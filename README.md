# Real-Time Embedded Game Engine (ATmega32)

## 🚀 Overview
This project is a high-performance, real-time graphics rendering engine and game logic kernel developed for the **AVR ATmega32** microcontroller. 

Unlike standard implementations, this project utilizes **pure Assembly** for critical rendering paths and a custom **Interrupt-Driven Architecture**, bypassing high-level libraries to achieve direct hardware control within strict **2KB SRAM** constraints.

**Key Engineering Feat:** The system runs on a deterministic 20Hz loop managed by hardware timers, ensuring consistent physics calculations regardless of the rendering load, optimized for low-power operation at **1MHz**.

## 🛠 Hardware Architecture
* **MCU:** ATmega32 (8-bit AVR RISC Architecture)
* **Display:** 128x64 Graphical LCD (GLCD) with KS0108 Controller
* **Input:** Resistive Touch Panel (Processed via ADC)
* **Scoreboard:** 16x9 LED Matrix (Driven via I2C/TWI protocol)
* **Simulation:** Proteus / ISIS

## ⚙️ Technical Highlights

### 1. Bare-Metal Graphics Engine
Implemented a custom "Paging & Column" rendering system to manipulate GLCD memory directly.
* **Split-Screen Synchronization:** Solved timing artifacts between the Left (CS1) and Right (CS2) display drivers using custom wrapper routines (`glcdDataWriteWrapping`).
* **Sprite Management:** Optimized drawing routines for dynamic objects (Player, Enemies, Bullets) with minimal cycle overhead.

### 2. Interrupt-Driven Kernel
The system avoids blocking `delay()` loops. Instead, it utilizes **Timer1 in CTC Mode**:
* A precise interrupt fires at **20Hz**.
* The main loop sleeps until the interrupt sets a global `GameTick` flag.
* This ensures stable frame rates and separates game logic from rendering.

### 3. Low-Power Design Optimization
* **Clock Speed:** The system is engineered to run efficiently at **1MHz (Internal Oscillator)**.
* Instead of increasing clock speed (which increases power consumption), code efficiency was prioritized to fit all calculations within the 1MHz cycle budget, demonstrating a **Power-Constraint Engineering** approach.

### 4. Analog Input & Physics
* **ADC Thresholding:** Movement is controlled by reading voltage levels from the touch panel. A custom algorithm creates a "Dead Zone" to prevent jitter and interprets analog values as digital direction flags.
* **Collision Detection:** Implemented bounding-box collision logic optimized for 8-bit register arithmetic.

## 📊 Logic Flowchart
The following diagram illustrates the Interrupt-Driven Kernel architecture:

```mermaid
graph TD
    Start((Power On)) --> Init[System Initialization]
    Init --> I2C_Init[Init I2C & LED Matrix]
    Init --> GLCD_Init[Init GLCD & Clear Screen]
    Init --> ADC_Init[Init ADC for Touch Input]
    Init --> Timer_Init[Init Timer1 CTC Mode @ 20Hz]
    Init --> Loop_Start{Main Loop}

    subgraph "Interrupt Service Routine (ISR)"
        Timer_Tick[Timer1 Compare Match] --> Set_Flag[Set 'Game Tick' Flag]
        Set_Flag --> Return_ISR[Return from Interrupt]
    end

    Loop_Start -->|Wait for Tick Flag| Check_Flag{Is Tick Flag Set?}
    Check_Flag -- No --> Loop_Start
    Check_Flag -- Yes --> Clear_Flag[Clear Flag]
    
    Clear_Flag --> Input[Read Analog Touch Input]
    Input --> Logic_Player[Update Player Position]
    Logic_Player --> Logic_Bullet[Process Bullets & Shooting]
    Logic_Bullet --> Logic_Enemy[Move Enemies / Wave Logic]
    Logic_Enemy --> Collision{Collision Check}
    
    Collision -- Yes --> GameOver[Set Game Over Flag]
    Collision -- No --> Refresh[Update GLCD Buffer]
    
    Refresh --> Loop_Start
    GameOver --> Halt((System Halt / Game Over Screen))

    Timer_Init -.-> Timer_Tick
