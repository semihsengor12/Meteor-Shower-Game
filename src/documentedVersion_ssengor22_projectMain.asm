;
; project_embedded.asm
;
; Created: 1.01.2026 10:32:39
; Author : Semih Eren Şengör
;


; Replace with your application code


.def flags = r22
.def temp = r16
.def temp2 = r17
.def temp3 = r24
.def command = r21
.def xCoordinates = r18	// selects paging rows and columns
.def yCoordinates = r19 //
.def score = r20 
.def adcValue = r23
.def scoreDiff = r25
.def xLow = r26
.def xHigh = r27
.def yLow = r28
.def yHigh = r29


// 
.equ ledMatrixResetPin = 5


// port directions
.equ dataDirection  = DDRC
.equ dataPort = PORTC



// FLAG BITS
.equ flagTimer = 0      // timer tick
.equ flagRight = 1      // right intent
.equ flagLeft  = 2		// left intent
.equ flagOver = 3		// game overFlag
.equ flagWin = 4		// win flag
.equ flagDisplay = 5 // display flag depricated now 
.equ flagSecondWave = 7		// second wave is active
// touch panel 
.equ driveA = 2
.equ readPin = 0			// PA2 is busy with GLCD

.equ playerWidth = 7	// constants
.equ enemyWidth = 6
.equ bulletWidth = 3



.equ matrixAdress = 0xe8
//settings	// you can change to make 
.equ enemyCount = 10
.equ spawnLineNumber = enemyCount/2
.equ enemyInitSpeed = 10 // FPS/enemyInitSpeed so actually it is a prescaler
.equ difficultyMultiplier = 30
.equ sideMargin = 2
// assembler calculations do  not alter these
.equ zoneWidth = 128 / spawnLineNumber
.equ maxOffset = zoneWidth- sideMargin - enemyWidth
.equ bulletSpeedLimit = 2

.dseg
playerX: .byte 1
playerY: .byte 1



enemiesX: .byte enemyCount 
enemiesY: .byte enemyCount
enemySpeedCount: .byte 1
enemySpeedReset: .byte 1

randomSeed: .byte 1     // rng için lazım


.cseg



.org 0x00
	jmp reset
.org $00E
	jmp gameSpeed



reset:
    ldi 	TEMP, low(RAMEND)	; initialize stack pointer
	out		SPL, TEMP
	ldi 	TEMP, high(RAMEND)
	out 	SPH, TEMP
start:
	clr score

	// initiliaze matrix and i2c communication
    rcall init_i2c          
    rcall init_matrix      
    rcall updateScoreMatrix 
    rcall i2cDisable       	
	rcall glcdPowerOnDelay // wait a little there is some voltage changes here

	// init glcd and clear it
	rcall init_GLCD
	rcall init_ADC
	rcall glcdClear
	rcall initBullet
	rcall init_playerPosition 
	rcall init_enemies
	rcall init_tickTimer

	clr flags
	sei
	rjmp main



gameSpeed:
	push temp
	in temp, sreg
	push temp


	sbr flags, (1<<flagTimer) 


	pop temp
	out sreg, temp
	pop temp
	reti


main:

	sbrs flags, flagTimer
	rjmp main
	cbr flags, (1<<flagTimer) // clear flag
	rcall readTouchInput // go left or right set flagne
	rcall movePlayerPosition // move player
	rcall processBullet
	rcall moveEnemies // move enemies
	rcall checkCollusion



	sbrc flags, flagOver    
    rjmp haltSystem 
	sbrc flags, flagWin
	rjmp haltSystem

	rjmp main

haltSystem:
	rcall glcdClear
haltLoop:
	rjmp haltLoop // it waits here if collusion is detected


	rjmp main



/*
	ERASER AND DRAWERS:
	drawSpaceShip: Draws the spaceship sprite to GLCD. goToLocation must be used before calling this function.
	drawPlayer: A wrapper for drawing the player to GLCD.
	eraseSpaceShip: Erases spaceship by loading 0x00 to all 7 blocks.
	erasePlayer: A wrapper for erasing player to GLCD.
	drawAsteroid: Draws asteroid in given location.
	drawEnemy: A wrapper for drawing enemy.
	eraseEnemy: A wrapper for erasing enemy.
	eraseAsteroid: Erases asteroid sprite.
	drawBullet: Draws the bullet sprite to given location. P.S: Bullet logic was one of the last logics I implemented, and to prevent register collision all together I may or may not used unnecessary push and pops
	eraseBullet: Erases the bullet sprite
*/

drawPlayer:
	lds xCoordinates, playerX
	lds yCoordinates, playerY
		
	rcall glcdGotoLocation	// go to start of the 
	rcall drawSpaceShip
		
	ret
drawSpaceShip: // sprite of spaceShip
	ldi command, 0x60   	//automatic increment allow me to just send data
    rcall glcdDataWriteWrapping
    
    ldi command, 0x70     
    rcall glcdDataWriteWrapping
    
    ldi command, 0x78     
    rcall glcdDataWriteWrapping
    
    ldi command, 0xFC     
    rcall glcdDataWriteWrapping
    
    ldi command, 0x78     
    rcall glcdDataWriteWrapping
    
    ldi command, 0x70     
    rcall glcdDataWriteWrapping
    
    ldi	  command, 0x60    
    rcall glcdDataWriteWrapping

    ret
eraseSpaceShip: // erase ship
	ldi command, 0x00 	//automatic increment allow me to just send data
    rcall glcdDataWriteWrapping    
    rcall glcdDataWriteWrapping    
    rcall glcdDataWriteWrapping	
    rcall glcdDataWriteWrapping 
    rcall glcdDataWriteWrapping 
    rcall glcdDataWriteWrapping    
    rcall glcdDataWriteWrapping
    ret
erasePlayer: // wrapper for erasing
	lds xCoordinates, playerX
	lds yCoordinates, playerY
	push xCoordinates
	rcall glcdGotoLocation
	rcall eraseSpaceShip
	rcall delayForGLCD
	pop xCoordinates
	ret
drawAsteroid:
	ldi command, 0x3C     
    rcall glcdDataWriteWrapping
    ldi command, 0x7E     
    rcall glcdDataWriteWrapping
    ldi command, 0xFF     
    rcall glcdDataWriteWrapping
    ldi command, 0xFF    
    rcall glcdDataWriteWrapping
    ldi command, 0x7E    
    rcall glcdDataWriteWrapping
    ldi command, 0x3C     
    rcall glcdDataWriteWrapping
    ret
eraseAsteroid:
    ldi command, 0x00
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    ret
drawEnemy:
	rcall glcdGotoLocation
	rcall drawAsteroid
	rcall delayForGLCD

	ret
eraseEnemy:
	push xCoordinates
	rcall glcdGotoLocation
	rcall eraseAsteroid
	rcall delayForGLCD
	pop xCoordinates
	ret

drawBullet:
    push temp
    push xCoordinates
    push yCoordinates
    push command
    
    lds temp, bulletX
    mov xCoordinates, temp
    lds temp, bulletY
    mov yCoordinates, temp
    
    rcall glcdGotoLocation
    
   
    ldi command, 0x18       
    rcall glcdDataWriteWrapping
    ldi command, 0x3C       
    rcall glcdDataWriteWrapping
    ldi command, 0x18    
    rcall glcdDataWriteWrapping
    
    pop command
    pop yCoordinates
    pop xCoordinates
    pop temp
    ret
eraseBullet:
    push temp
    push xCoordinates
    push yCoordinates
    push command
    
    lds temp, bulletX
    mov xCoordinates, temp
    lds temp, bulletY
    mov yCoordinates, temp
    
    rcall glcdGotoLocation
    
    ldi command, 0x00
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    rcall glcdDataWriteWrapping
    
    pop command
    pop yCoordinates
    pop xCoordinates
    pop temp
    ret




/*
	ADC and PLAYER MOVEMENT
	movePlayerPosition: Checks if flagRight or flagLeft is set if set erases the player and draws the player in the new position, it also has boundary control to make sure the program still is valid for GLCD. 
	+3 or -3 in X direction

	readTouchInput:	Resets the residual flagsLeft or FlagRight, discharges input pin, gives DRIVEA 5v gives DRIVEB 0 V and reads the voltage in READ-X, and then this voltage is used to raise movement intent flags.


*/




/** INPUT: flag register second and third bit
*	Functionality: If user wants to move the spaceship it first erases the spaceship and reloads it in left/right direction.
*/
movePlayerPosition:
	lds xCoordinates, playerX // OPTIMIZATION WARNING CHECK HERE 
	lds yCoordinates, playerY
controlRight:	
	sbrs flags, flagRight // 01 right 10 left 00 empty 11 is also right right priority
	rjmp controlLeft
	rcall erasePlayer
	lds temp, playerX
	inc temp
	inc temp
	inc temp
	cpi temp, 120 // space ship start 7 pixel width spaceship max 0 to 127
	brsh limitRight
	sts playerX, temp
	rjmp moveEnd
controlLeft:
	sbrs flags, flagLeft
	rjmp moveEnd
	rcall erasePlayer
	lds temp, playerX
	dec temp
	dec temp
	dec temp		// if negative flag is raised by this instruction 
	brmi limitLeft
	sts playerX, temp
	rjmp moveEnd
limitRight:
	ldi temp, 120
	sts playerX, temp
	rjmp moveEnd
limitLeft:
	ldi temp, 0
	sts playerX, temp
moveEnd:
	rcall drawPlayer
	ret

readTouchInput:

	cbi glcdEnablePort, glcdEnablePin

	cbr flags, (1<<flagRight) | (1<<flagLeft) // forget previous input
	// PA0 and PA1 output, P2 input

	in temp, ddra
	in temp2, porta

	
    sbi DDRA, 0	// discharge
    cbi PORTA, 0   // discharge
    nop
    nop              
   


	cbi DDRA, 0      // input	
    cbi DDRA, 1       // input
    cbi PORTA, 0      // no pull up
    cbi PORTA, 1     // no pull up

    sbi DDRA, 2      // pa2 output
    sbi PORTA, 2     //drive A 5V
    sbi DDRA, 3		// pa3 output
    cbi PORTA, 3      // driveB grnd	 // do not forget here
	
	push temp
	rcall  delayForGLCD
	pop temp
	// wait for stability


	sbi ADCSRA, ADSC	// start conversion
waitDiscard:
    sbic ADCSRA, ADSC	// wait until conversion finishes
    rjmp waitDiscard	// first conversion is basically trash i discard it
		
    sbi ADCSRA, ADSC // start real conversion
waitConversion:
	sbic ADCSRA, ADSC
	rjmp waitConversion
	in adcValue, ADCH // read 8 bit resolution 

	out ddra, temp	// restore values of ddra and porta  
	out porta, temp2  

	rcall decideFlags // helper for deciding which way to go

	ret

decideFlags:
	cpi adcValue, 20
	brlo decideDone
	cpi adcValue, 80 // 20-80 Left
	brlo setLeftFlag
	cpi adcValue, 170 // 170-255 right between 80 and 170 is empty
	brsh setRightFlag
	rjmp decideDone
setLeftFlag:
	sbr flags, (1<<flagLeft)
	rjmp decideDone
setRightFlag:
	sbr flags, (1<<flagRight)
decideDone:
	ret




/*
HELPERS AND MATH FUNCTIONS
	getRandomNumber: RNG generator, uses 
	
	multiplication: Returns zone offset in temp3. 

*/



getRandomNumber:
    push temp2
    
    lds temp, randomSeed 
    
    mov temp2, temp
    lsl temp2          
    eor temp, temp2    
    
    mov temp2, temp
    lsr temp2             
    eor temp, temp2       
    
    in temp2, TCNT1L       
    eor temp, temp2      
    
    sts randomSeed, temp 
    
    pop temp2
    ret











// temp2 is index and temp 3 is the accumulator  just index*zonewidth zonewidth is calculated by assembler
multiplication:
	push temp
	push temp2
	cpi temp2, spawnLineNumber
	brlo sub5
	subi temp2, spawnLineNumber
sub5:
	mov temp, temp2
	clr temp3 // accumulator
	tst temp2
	breq mulDone
multipLoop:
	subi temp3, -zoneWidth
	dec temp
	brne multipLoop
mulDone:
	pop temp2
	pop temp
	ret
/*	DIFFICULTY ADJUSTER
	difficulty multiplier means that when score reaches this number the prescaler will get -1
	
*/

increaseDifficulty:
	cpi scoreDiff, difficultyMultiplier
	brlo increaseDifficultyEnd
	lds temp, enemySpeedReset
	dec temp
	sts enemySpeedReset, temp
	clr scoreDiff
increaseDifficultyEnd:
	ret


/*	Enemy moving, respawning, inactive enemies logic.
	moveEnemies: I think this is the largest subroutine in this program,
	It traverses all enemies from SRAM, if enemies are inactive, i.e y= 254 it skips them, and make them active when the last indexed member of first wave reaches fourth page.
	If Y = 255, it means the asteroid is got shot and it is waiting for respawn.
	If Y = 8 it means asteroid has gotten out of the screen and it will respawn immediately. This is wave generator rather than indivual spawning.

	spawnSecondWave:
	Spawns the second wave after first wave reaches fourth page.
	checkSafeToSpawn:
	Checks if the partner has enough space to avoid GLCD collisions. Returns temp3 = 1 if safe and if not 0.
	activateSecondWave:

*/




checkSafeToSpawn:
    push temp
    push XL
    push XH
    push YL
    push YH
    push temp2
	
    ldi temp, enemyCount
    sub temp, temp2
    
    cpi temp, spawnLineNumber	// first wave
    brlo partnerPlus
    subi temp, spawnLineNumber	// second wave // partner is in first wave
    rjmp checkPartnerY
partnerPlus:
    subi temp, -spawnLineNumber	// partner is in second wave
    
checkPartnerY:
    ldi YL, low(enemiesY)
    ldi YH, high(enemiesY)
    add YL, temp	// get the memory adress pointing to coordinates
    brcc noCarryY	// if carry add one if not go noCarry
    inc YH
noCarryY:
    ld temp, Y 
    cpi temp, 8
	breq notSafe
    cpi temp, 255	// if dead it is safe
    breq isSafe
    cpi temp, 3		// if page difference is 3 then it is safe
    brsh isSafe
notSafe:
   
    ldi temp3, 0
    rjmp checkSafeEnd

isSafe:
    ldi temp3, 1

checkSafeEnd:
	pop temp2
    pop YH
    pop YL
    pop XH
    pop XL
    pop temp
    ret


spawnSecondWave:
	
	push temp2
	push xLow
	push xHigh
	push yLow
	push yHigh
	push xCoordinates
	push yCoordinates

	ldi xLow, low(enemiesX + spawnLineNumber)	// get the start of second wave
    ldi xHigh, high(enemiesX + spawnLineNumber)
    ldi yLow, low(enemiesY + spawnLineNumber)
    ldi yHigh, high(enemiesY + spawnLineNumber)
	ldi temp2, spawnLineNumber	
	
spawnLoop:

	ld xCoordinates, X		// x was already set in initilization
	ldi yCoordinates, 0	// spawn tem
	st Y, yCoordinates	// store Y
					
	rcall drawEnemy	// draw enemy and go to next member of second wave
	
	adiw xLow, 1
	adiw yLow, 1
	dec temp2
	brne spawnLoop

	pop yCoordinates
	pop xCoordinates
	pop yHigh
	pop yLow
	pop xHigh
	pop xLow
	pop temp2

	ret





moveEnemies:
	lds temp, enemySpeedCount
	dec temp
	sts enemySpeedCount, temp
	tst temp
	breq moveSucess
moveFailure:
	ret
moveSucess:
	lds temp, enemySpeedReset // set the speed back to init level
	sts enemySpeedCount, temp
	 
	ldi xLow, low(enemiesX)
    ldi xHigh, high(enemiesX)
    ldi yLow, low(enemiesY)
    ldi yHigh, high(enemiesY)

	ldi temp2, enemyCount
loopEnemies:
	ld xCoordinates, X      // get the ram adress x points
    ld yCoordinates, Y      // get the ram adress y points

	cpi yCoordinates, 254	// if 254 inactive skip them
	breq skipInactives
	cpi yCoordinates, 255	// try to respawn shot asteroids
	breq tryRespawn


	rcall eraseEnemy
		
	ld temp, Y			//  increase Y 
	inc temp
	mov yCoordinates, temp
	st Y, yCoordinates

	cpi temp, 4
	breq activateSecondWave


	cpi temp, 8	 // check if its on page 8
	breq respawnEnemy	// this respawns directly

	rjmp moveEnemiesEnd

tryRespawn:
	push temp3
    rcall checkSafeToSpawn
    tst temp3
	pop temp3
    breq skipInactives // if checktospawn did not return safe skip for now
    
    // if it is safe spawn the asteroid
    ldi temp, 0
    st Y, temp
    mov yCoordinates, temp
    
    // start of calculating the new randomized X in the specified zone
    push XL
    push XH
    push temp2
    
    // index in the ram = enemycounr - temp2 which is used for counting
    ldi temp, enemyCount
    sub temp, temp2
    mov temp2, temp
    // multiplication uses temp2 as index and temp3 as accumulator

    rcall multiplication
    rcall getRandomNumber

    andi temp, 0x1F // mask it between 0-31
    cpi temp, maxOffset // if mask > max make max  maxOffset is calculated with assembler
    brlo setReviveX
    ldi temp, maxOffset
setReviveX:
    add temp3, temp
    subi temp3, -sideMargin
    st X, temp3
    mov xCoordinates, temp3
   
    pop temp2
    pop XH
    pop XL
    
    rcall drawEnemy
    rjmp skip

activateSecondWave:	
	cpi temp2, spawnLineNumber+1
	brne moveEnemiesEnd

	sbrc flags, flagSecondWave
	rjmp moveEnemiesEnd
	rcall spawnSecondWave
	sbr flags, (1<<flagSecondWave)
	ret

// branch limit problem
skipInactives:
	rjmp skip

middleStep1:
	rjmp loopEnemies
respawnEnemy:
	inc scoreDiff
	rcall increaseDifficulty

	cpi score, 255
	breq youWin
	inc score


	rjmp afterScore
youWin:
	sbrc flags, flagWin	
	rjmp afterScore
	sbr flags, (1<<flagWin)
afterScore:
	//update score
	rcall init_i2c         
    rcall updateScoreMatrix 
    rcall i2cDisable        

	ldi yCoordinates, 0
	st Y, yCoordinates

	push temp2
	ldi temp, enemyCount //
	sub temp, temp2	// get index for respective blocks index = 5 - i == 5start
	mov temp2, temp
	rcall multiplication
	rcall getRandomNumber
	andi temp, 0x1F
	cpi temp, maxOffset
	brlo setRespawnOffset
    ldi temp, maxOffset
setRespawnOffset:
	add temp3, temp
    subi temp3, -sideMargin
    st X, temp3            
    mov xCoordinates, temp3 
    
    pop temp2
	

moveEnemiesEnd:
	rcall drawEnemy
skip:
	adiw xLow, 1 // move to next ram adress
	adiw yLow, 1 // move to next ram adress
	dec temp2 // if looped through all enemies return back if not move the other 
	brne middleStep1	
	ret
/*

	Collusion of enemy and player

	checkCollusion:
	First check if enemy is on 7th page, if not skip. Then check the X variable. If the asteroid is right to player check if the distance is smaller than playerWidth if it is left to player check the enemyWidth:
	and If collusion is detected raise over flag.


*/

checkCollusion:
	lds xCoordinates, playerX

	ldi xLow, low(enemiesX)
    ldi xHigh, high(enemiesX)
    ldi yLow, low(enemiesY)
    ldi yHigh, high(enemiesY)

	ldi temp, enemyCount

loopCollusion:
	ld temp2, X
	ld temp3, Y
	cpi temp3,7	// we check if enemy is on the 7.th line
	breq checkXdimension
	rjmp nextEnemy
checkXdimension:
	mov temp3, xCoordinates
	sub temp3, temp2
	brcs enemyOnTheRight
enemyOnTheLeft:
	cpi temp3, enemyWidth
	brlo gameOver
	rjmp nextEnemy

enemyOnTheRight:
	neg temp3
	cpi temp3, playerWidth
	brlo gameOver

nextEnemy:
	adiw xLow, 1 
	adiw yLow, 1
	dec temp
	brne loopCollusion
	ret
gameOver:
	sbr flags, (1<<flagOver)
	ret


/*
The TWINT Flag must be cleared by software by writing a logic one to it. Note that this flag is not
automatically cleared by hardware when executing the interrupt routine. Also note that clearing
this flag starts the operation of the TWI, so all accesses to the TWI Address Register (TWAR),
TWI Status Register (TWSR), and TWI Data Register (TWDR) must be complete before clearing
this flag. DATASHEET PAGE 177
*/


/*
	I2C and 16x9 matrix functions:

	init_i2c: sets up speed rate and prescaler
	i2cDisable: Cuts the connection, and gives back the control of the portC to glcd.
	i2cStart: enables the interruots, and I2C, then sends start condition, if valid status code is returned it goes on if not it stops the communication:
	i2cStop: stops the communication:
	i2cWrite: Sends data through I2C, checks for status codes. This is used to select driver/registers or send normal data.
	i2cSendPacket: A wrapper for writing data temp3 gets the driver/register info and temp2 gets the normal data.
	updateScoreMatrix:

*/
init_i2c:
   
	// configures the speed of communication

    ldi temp, 72	// 2c freq = cpu clock/16 +2twbr* 4**TWPS
    out TWBR, temp
    ldi temp, 0       // prescaler is 0
    out TWSR, temp
    ret

i2cDisable:
    // disable the I2C communication give back portC to the GLCD
    clr temp
    out TWCR, temp
    ldi temp, 0xFF
    out dataDirection, temp
    ret

i2cStart:
    ldi temp, (1<<TWINT) | (1<<TWSTA) | (1<<TWEN)	// enable two wire communication enable interrupt to understand communication is ended, and start it 
    out TWCR, temp
waitStart:
    in temp, TWCR
    sbrs temp, TWINT
    rjmp waitStart
    
    in temp, TWSR // read status register gives status code for us
    andi temp, 0xF8     // mask the last 3 bits as those are prescalers
    cpi temp, 0x08      // start is send 
    breq startOK
    cpi temp, 0x10			// repeated start
    breq startOK
    rcall i2cStop	// if not cut the communication
    ret
startOK:
    ret

i2cStop:
    ldi temp, (1<<TWINT) | (1<<TWSTO) | (1<<TWEN)
    out TWCR, temp
waitStop:
    in temp, TWCR
    sbrc temp, TWSTO    
    rjmp waitStop
    ret

i2cWrite:
    out TWDR, temp	// load data to register
    ldi temp, (1<<TWINT) | (1<<TWEN)	// send data
    out TWCR, temp
waitWrite:
    in temp, TWCR
    sbrs temp, TWINT
    rjmp waitWrite // wait the data to arrive
    
    in temp, TWSR // check status register
    andi temp, 0xF8 // mask the last3
    cpi temp, 0x18 // data is driver adress
    breq writeOK
    cpi temp, 0x28 // data is normal data
    breq writeOK
    rcall i2cStop
    ret
writeOK:
    ret

i2cSendPacket: // wrapper temp3 is driver/register temp2 is normal data
	push temp
    rcall i2cStart
    ldi temp, matrixAdress
    rcall i2cWrite
    mov temp, temp3
    rcall i2cWrite
    mov temp, temp2
    rcall i2cWrite
    rcall i2cStop
	pop temp
    ret



updateScoreMatrix:
    push temp3
	push temp2
	push temp


    ldi temp3, 0xfd // select command register
    ldi temp2, 0x00 // select frame 0
    rcall i2cSendPacket

    ldi temp3, 0xFD // go into command register
    ldi temp2, 0x0B // go to function page // settings
    rcall i2cSendPacket
    
    ldi temp3, 0x01	// select global current 
    ldi temp2, 0x10  // give the data to current
    rcall i2cSendPacket 
    
    ldi temp3, 0xFD
    ldi temp2, 0x00
    rcall i2cSendPacket
    
    rcall i2cStart
    ldi temp, matrixAdress
    rcall i2cWrite
    ldi temp, 0x24      // start adress of pwm register of first led
    rcall i2cWrite
    
    mov temp3, score
    ldi temp2, 8        
    
scoreLoop:	// light bits where 1 s are present in the score.
    ldi temp, 0x00     
    sbrc temp3, 0       
    ldi temp, 0x10     
    
    rcall i2cWrite      
    
    lsr temp3          
    dec temp2
    brne scoreLoop
    
    rcall i2cStop
	pop temp
	pop temp2
	pop temp3
    ret



/*
	Bullet and shooting system

*/
.equ bulletSpeed = 1          // one frame needed to move bullet
.equ FIRE_COOLDOWN = 16        // reloading time

.dseg
bulletX: .byte 1               
bulletY: .byte 1               
bulletActive: .byte 1         // if bulled active or not
bulletSpeedCount: .byte 1     // speed counter
bulletCooldown: .byte 1       // cooldown timer

.cseg

// initiliaze bullet 
initBullet:
    push temp
    
    clr temp
    sts bulletActive, temp
    sts bulletCooldown, temp
    
    ldi temp, bulletSpeed
    sts bulletSpeedCount, temp
    
    pop temp
    ret

/*


*/
processBullet:
    push temp
    push temp2
    push temp3
    
	// if bullet is active update it if not check cooldown
    lds temp, bulletActive
    tst temp
    brne updateActiveBullet
    

    lds temp, bulletCooldown
    tst temp
    breq trySpawnBullet    // cooldown is end spawn new bullet
    
	// cooldown is not finished decrease it 
    dec temp
    sts bulletCooldown, temp
    rjmp processBulletEnd

trySpawnBullet:
    
	// spawn a new unit from one page above player
    lds temp, playerX
    subi temp, -3           // Center of player (playerX + 3)
    sts bulletX, temp
    
    ldi temp, 6             // One page above player
    sts bulletY, temp
    
    ldi temp, 1
    sts bulletActive, temp // activate bullet
    
    ldi temp, bulletSpeed
    sts bulletSpeedCount, temp
    
    rcall drawBullet
    rjmp processBulletEnd

updateActiveBullet:
    //  check if bullet counter is 0
    lds temp, bulletSpeedCount
    dec temp
    sts bulletSpeedCount, temp
    tst temp
    brne processBulletEnd   // waiting for counter to reach 0
    
	// load back the counter
    ldi temp, bulletSpeed
    sts bulletSpeedCount, temp
    
    // check collision with asteroid before movement

    rcall checkBulletHit
    tst temp3
    brne bulletHitSomething  // hit is detected
    
	// no hit at current position erase the bullet
    rcall eraseBullet
    
    // up movement
    lds temp, bulletY
    dec temp
    brmi killBullet         // out of screen kill it
    sts bulletY, temp       // Update position
    
    // check collision at new position

    rcall checkBulletHit
    tst temp3
    brne bulletHitSomething 
    
    rcall drawBullet
    rjmp processBulletEnd

bulletHitSomething:
    rcall eraseBullet
    rjmp killBullet

processBulletEnd:
    pop temp3
    pop temp2
    pop temp
    ret

killBullet:
    // deactivate bullet
    clr temp
    sts bulletActive, temp
    
	// set reloading time
    ldi temp, FIRE_COOLDOWN
    sts bulletCooldown, temp
    
    rjmp processBulletEnd




checkBulletHit:
    push temp
    push temp2
    push XL
    push XH
    push YL
    push YH
    push xCoordinates
    push yCoordinates
    

    lds xCoordinates, bulletX    
    lds yCoordinates, bulletY    // get bullet info
    
	// loop through enemies
    ldi XL, low(enemiesX)
    ldi XH, high(enemiesX)
    ldi YL, low(enemiesY)
    ldi YH, high(enemiesY)
    ldi temp2, enemyCount
    
checkEnemyLoop:
    ld temp, Y             
    cp temp, yCoordinates  // if Y's do not match go next enemy
    brne nextEnemyBullet
    
    ld temp, X              
    mov temp3, xCoordinates

    sub temp3, temp         // temp3 = bulletX - enemyX
    brcs checkLeftOverlap   // if carry bullet is left of enemy, similiar to asteroid collision logic
    
    cpi temp3, playerWidth	// if not right and compare with playerWidth
    brlo directHit          //
    rjmp nextEnemyBullet

checkLeftOverlap:
   // if left compare it with bulletWidth +1
    neg temp3           
    cpi temp3, bulletWidth+1        
    brlo directHit

nextEnemyBullet:
    adiw XL, 1	// go next enemy
    adiw YL, 1
    dec temp2
    brne checkEnemyLoop
    
    // no hit load temp3 0 and return
    ldi temp3, 0
    rjmp checkHitEnd

directHit:
    cpi score, 250
    brsh hitWin
    ldi temp, 5
    add score, temp

	rjmp skipScoreUpdate
hitWin:
	ldi score, 255
	sbr flags, (1<<flagWin)

skipScoreUpdate:
    
    // erase enemy
    ld temp, X
    mov xCoordinates, temp
    ld temp, Y
    mov yCoordinates, temp
    
    push XL
    push XH
    push YL
    push YH
    push temp2
    rcall eraseEnemy
    pop temp2
    pop YH
    pop YL
    pop XH
    pop XL
    
    // give enemy 255 wait for moveEnemy to respawn it 
    ldi temp, 255
    st Y, temp              
    
   
    
    ldi temp3, 1
	
	push temp3
	push temp2
	push temp
	
	// update score
	rcall init_i2c      
    rcall updateScoreMatrix 
    rcall i2cDisable        
	
	pop temp
	pop temp2
	pop temp3
checkHitEnd:
    pop yCoordinates
    pop xCoordinates
    pop YH
    pop YL
    pop XH
    pop XL
    pop temp2
    pop temp
    ret



	/*
	INIT FUNCTIONS:
	init_tickTimer: Main driver of the game sets up the FPS rate, it runs on timer1 CTC	mode resets after 50k cycle TOTAL 20 FPS:
	init_ADC: Sets up ADC module's Heartz to 125KHz sets READ-X and READ-Y input, left adjust is selected. PA2 and PA3 is not initiliazed here to prevent pin collision. 5V ref voltage, PA0 is input.
	init_GLCD: sets the direction of control and data pins, sets up both screens to be available for displaying.
	init_enemies: Initiliazes the enemies locations. Enemies are located in X with the following formula: X=base + offset, base is determined through the multiplication subroutine this routine divides
	128 pixels of GLCD screen into equal lines equal to enemiesCount/2. As index of the enemies grow, the base grows as fell. Offset is determined through getRandomNumber subroutine. It uses a seed
	and a random value from TCNT1 to increase randomness, then it is masked and finally comparef with maximumOffset possible. Furthermore, this function loads 254 to inactive enemies at initilization.
	init_matrix: Resets the hardware both from software and hardware, wakes up the matrix from sleep mode, sets up picture mode, enables first 8 leds.
	init_playerPosition: Sets up the player coordinates, and draws the player.
	*/
init_tickTimer: // 0xc35a = 50.010 and there is dispatch latency of jump so 50k cycle = 20Hz 20 FPS
	ldi r16, 0xC3       
    out OCR1AH, r16
    ldi r16, 0x4d     
    out OCR1AL, r16
	ldi r16, (1 << WGM12) | (1 << CS10) // CTC mode ve 1 prescale
	out TCCR1B, r16
	in r16, TIMSK
    ori r16, (1 << OCIE1A) // enable interrupt without resetting timsk
    out TIMSK, r16
init_ADC:
	cbi DDRA, 0     
    cbi DDRA, 1     
	// i am skipping PA2 AND PA3

	// REFS0 1 REFS1 0 AVCC with external capacitor at AREF pin ADLAR left adjust so we will get the 8 bit
	ldi temp, (1<<REFS0) | (1<<ADLAR) // PA0 is input for ADC
    out ADMUX, temp
	ldi temp, (1<<ADEN) | (1<<ADPS1) | (1<<ADPS0)	//aden enable adc  0  1  1 is prescale 8 and 1MHz cpu and ideal range is between 50-200KHz my is 125KHz prescale of ADC unit
	out ADCSRA, temp
    ret
init_GLCD:
	clr temp
	ldi temp, 0xff
	
	// SET ALL THESE PINS OUTPUT 
	out dataDirection, temp
	sbi glcdRegisterSelectDirection, glcdRegisterSelectPin
	sbi glcdSelectPortDirection, glcdLeft
	sbi glcdSelectPortDirection, glcdRight
	sbi glcdRWDirection, glcdRWPin
	sbi glcdEnableDirection, glcdEnablePin
	sbi glcdResetDirection, glcdResetPin

	cbi glcdRWPort, glcdRWPin  // write mode
	
	cbi glcdResetPort, glcdResetPin // reset glcd
	rcall delayForGLCD
	rcall delayForGLCD
	rcall delayForGLCD
	rcall delayForGLCD
	rcall delayForGLCD
	sbi glcdResetPort, glcdResetPin

	// turn on both screens and set the start line

	sbi glcdSelectPort, glcdLeft
	cbi glcdSelectPort, glcdRight
	ldi command, 0x3F
	rcall glcdSendCommand
	ldi command, 0xc0
	rcall glcdSendCommand
	cbi glcdSelectPort, glcdLeft
	sbi glcdSelectPort, glcdRight
	ldi command, 0x3F	// ekran açma 
	rcall glcdSendCommand
	ldi command, 0xc0	// set start line
	rcall glcdSendCommand
	ret
init_enemies:
	ldi temp, enemyInitSpeed	// get the initial speed from .equ and load it both into speed prescaler and counter
	sts enemySpeedReset, temp
	sts enemySpeedCount, temp

	ldi xLow, low(enemiesX)  // get sramm adress to X register
    ldi xHigh, high(enemiesX)
	ldi yLow, low(enemiesY)  // get sramm adress to y register
    ldi yHigh, high(enemiesY) 
	
	ldi temp2, 0 // index counter

init_enemiesLoop:
	rcall multiplication // temp3 holds the index number
	rcall getRandomNumber

	andi temp, 0x1F //
	cpi temp, maxOffset
	brlo setOffset
	ldi temp, maxOffset
	 
setOffset:
	add temp3, temp
	subi temp3, -sideMargin // left margin we created a right margin in the .equ statement
	mov xCoordinates, temp3

	st X+, xCoordinates // store X coordinates

	cpi temp2, (spawnLineNumber)
	brsh secondWaveY
	ldi yCoordinates, 0
	rjmp afterY
secondWaveY:
	ldi yCoordinates, 254
afterY:

    st Y+, yCoordinates // store Y coordinates

	cpi yCoordinates, 254
	breq skipDraw
	rcall drawEnemy

skipDraw:
	inc temp2 // go to next enemy	
	cpi temp2, enemyCount
	brne init_enemiesLoop
	ret

init_matrix:
	// hardware reset
    sbi DDRA, ledMatrixResetPin
    cbi PORTA, ledMatrixResetPin
    rcall glcdPowerOnDelay // wait a little let it stabilize
    sbi PORTA, ledMatrixResetPin
    rcall glcdPowerOnDelay

   //  Function Page Setup
    ldi temp3, 0xFD	//command register
    ldi temp2, 0x0B    // function page
    rcall i2cSendPacket
    
	// wake up the matrix
    ldi temp3, 0x0A
    ldi temp2, 0x01     
    rcall i2cSendPacket
    
    // get to picture mode
    ldi temp3, 0x00
    ldi temp2, 0x00
    rcall i2cSendPacket

    // get to frame 0
    ldi temp3, 0x01
    ldi temp2, 0x00
    rcall i2cSendPacket
    
    // get to page 0 again
    ldi temp3, 0xFD
    ldi temp2, 0x00     
    rcall i2cSendPacket
    
    // disable all leds
    rcall i2cStart
    ldi temp, matrixAdress
    rcall i2cWrite
    ldi temp, 0x00      
    rcall i2cWrite
    
    ldi temp2, 18    // 18 registers * 8 = 144 leds
clearEnableLoop:
    ldi temp, 0x00      // 
    rcall i2cWrite
    dec temp2
    brne clearEnableLoop
    rcall i2cStop
    
    // disable pwms 
    rcall i2cStart
    ldi temp, matrixAdress
    rcall i2cWrite
    ldi temp, 0x24     // tart adress of pwm 
    rcall i2cWrite
    
    ldi temp2, 144      // total of 144 pwm register
clearPWMLoop:
	rcall delayForGLCD
    ldi temp, 0x00      // make duty cylce 0
    rcall i2cWrite
    dec temp2
    brne clearPWMLoop
    rcall i2cStop
    

    ldi temp3, 0x00    // enable the first 8 Leds
    ldi temp2, 0xFF    
    rcall i2cSendPacket
    
    rcall glcdPowerOnDelay
    ret
init_playerPosition:
	ldi temp, 60
	sts playerX, temp
	ldi temp, 7
	sts playerY, temp

	rcall drawPlayer
	ret




/*
	END OF INIT FUNCTIONS
	END OF INIT FUNCTIONS
	END OF INIT FUNCTIONS


*/
	

/*  GLCD "gOps" Subroutines and constants

	glcdPowerOnDelay: A blocking delay for GLCD and other hardwares to stabilize, a breathing delay in a sense.
	glcdClear: Clears the screen.
	glcdSendCommand: Selects the command mode, and sends the command data in the command register to GLCD.
	glcdSendData: Selects the data mode, and sends the data in the command register to GLCD.
	glcdGotoLocation: Parameters are xCoordinates, and yCoordinates takes these inputs and routes GLCD to point to those pixels. It is functional for both screens. if x < 64 left screen if bigger 
	right screen.
	delayForGLCD: A smaller delay for GLCD, initially used for enabling/disenabling wait.
	glcdDataWriteWrapping: It alters the selected screen when a animation sprite is distributed between the screens.



*/
// screen select
.equ glcdSelectPort = PORTB
.equ glcdSelectPortDirection = DDRB
.equ glcdLeft = 1  
.equ glcdRight = 0  

// RS and RW ports and pins
.equ glcdRegisterSelectPort = PORTA
.equ glcdRegisterSelectDirection = DDRA
.equ glcdRegisterSelectPin = 2
.equ glcdRWPort  = PORTA
.equ glcdRWDirection   = DDRA
.equ glcdRWPin   = 3

// enable pin and ports
.equ glcdEnablePort  = PORTD
.equ glcdEnableDirection   = DDRD
.equ glcdEnablePin   = 6

// reset pin and ports for glcd
.equ glcdResetPort = PORTD
.equ glcdResetDirection  = DDRD
.equ glcdResetPin  = 7


glcdPowerOnDelay:
    push temp2
    push temp3
    ldi temp3, 25
delayOuter:
    ldi temp2, 255      
delayInner:
    dec temp2
    brne delayInner    
    dec temp3
    brne delayOuter    
    pop temp3
    pop temp2
    ret

glcdClear:
	rcall glcdClearLeft
	rcall glcdClearRight
	ret
glcdClearLeft:
    cbi glcdSelectPort, glcdLeft
    sbi glcdSelectPort, glcdRight
	clr temp3	// page counter
glcdPageLoop:
	ldi command, 0xb8	// base page
	add command, temp3 	// base page + index
	rcall glcdSendCommand // go to page
	ldi command, 0x40
	rcall glcdSendCommand // go to column
	ldi temp2, 64		// column counter
glcdColumnLoop:
	ldi command, 0x00
	rcall glcdSendData
	dec temp2
	brne glcdColumnLoop
	inc temp3
	cpi temp3, 8
	brne glcdPageLoop
	ret	
glcdClearRight:
	sbi glcdSelectPort, glcdLeft
    cbi glcdSelectPort, glcdRight
	clr temp3
	rjmp glcdPageLoop

glcdSendCommand:
	cli
	cbi glcdEnablePort, glcdEnablePin // turn of sending

	cbi glcdRegisterSelectPort, glcdRegisterSelectPin // command mode
	out dataPort, command
	sbi glcdEnablePort, glcdEnablePin // trigger send
	nop
	nop
	nop
	nop
	nop		
	cbi glcdEnablePort, glcdEnablePin // turn of sending
	sei
	ret

glcdSendData:
	cli
	sbi glcdRegisterSelectPort, glcdRegisterSelectPin // data mode
	out dataPort, command
	sbi glcdEnablePort, glcdEnablePin // trigger send
	nop
	nop
	nop
	nop
	nop
	cbi glcdEnablePort, glcdEnablePin // turn of sending
	sei
	ret


glcdGotoLocation:
	
	push yCoordinates
	push xCoordinates
	push command
	cpi xCoordinates, 64
	brsh rightScreen

leftScreen:
	sbi glcdSelectPort, glcdLeft
	cbi glcdSelectPort, glcdRight
	rjmp setAdress
rightScreen:
	sbi glcdSelectPort, glcdRight
	cbi glcdSelectPort, glcdLeft
	subi xCoordinates, 64 // both screens is between 0-63 
setAdress:
	ldi command, 0xb8 // set page command
	add command, yCoordinates
	rcall glcdSendCommand
	ldi command, 0x40 // set column command
	add command, xCoordinates
	rcall glcdSendCommand
	
	pop command
	pop xCoordinates
	pop yCoordinates

	ret
	
delayForGLCD:
	ldi temp, 50
loopStart:
	cpi temp, 0
	breq loopEnd
	dec temp
	nop
	rjmp loopStart
loopEnd:
	ret
glcdDataWriteWrapping:
    rcall glcdSendData    // send the data be aware that this function requires that you must have used goToLocation before
    
    inc xCoordinates      // increase the coordinate in the soft ware glcd already has autoincrement
    
    cpi xCoordinates, 64   // if you are on the boundry you go to second chip
    breq switchChipRight
    ret

switchChipRight:
    cbi glcdSelectPort, glcdLeft
    sbi glcdSelectPort, glcdRight


	rcall glcdGotoLocation	// call go to location for the second chip

    ret