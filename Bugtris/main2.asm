
ExitProcess PROTO
RegisterClassA PROTO
GetModuleHandleA PROTO
CreateWindowExA PROTO
ShowWindow PROTO
GetLastError PROTO
DefWindowProcA PROTO
GetMessageA PROTO
TranslateMessage PROTO
DispatchMessageA PROTO
PostQuitMessage PROTO
SetTimer PROTO
InvalidateRect PROTO
BeginPaint PROTO
TextOutA PROTO
CreateSolidBrush PROTO
FillRect PROTO
DeleteObject PROTO
EndPaint PROTO
GetClientRect PROTO
GetTickCount PROTO
PlaySoundA PROTO

RECT struct
    left dd ?
    top dd ?
    right dd ?
    bottom dd ?
RECT ends

.data
     wndClass_start:
        wndClass_style          dd  0                       ; 4 bytes
        ; Align to 8-byte boundary
        align 8
        wndClass_wndProc        dq  0                       ; 8 bytes
        wndClass_cbClsExtra     dd  0                       ; 4 bytes
        wndClass_cbWndExtra     dd  0                       ; 4 bytes
        ; align 8 not needed, we have two dds above
        wndClass_hInstance      dq  0                       ; 8 bytes
        wndClass_hIcon          dq  0                       ; 8 bytes
        wndClass_hCursor        dq  0                       ; 8 bytes
        wndClass_hBrush         dq  0                       ; 8 bytes
        wndClass_menName        dq  0                       ; 8 bytes
        wndClass_className      dq  0                       ; 8 bytes
    wndClass_sizeof             EQU $ - wndClass_start   
        
.const                          ; Game settings ---
    myClassName                 db "TestKlasse", 0
    myWindowTitle               db "Tetris", 0

    GRID_SIZE_X                 EQU 20
    GRID_SIZE_Y                 EQU 30
    BLOCK_PIXEL_LENGTH          EQU 24

    GRID_NUM_ELEMENTS           EQU GRID_SIZE_X * GRID_SIZE_Y
    GRID_BYTE_SIZE              EQU GRID_NUM_ELEMENTS

.const                          ; Win32 Definitions ---
    WS_OVERLAPPEDWINDOW         EQU 13565952
    WS_SYSMENU                  EQU 00080000H
    CW_USEDEFAULT               EQU -2147483648
    WM_CREATE                   EQU 1
    WM_DESTROY                  EQU 2
    WM_PAINT                    EQU 15
    WM_TIMER                    EQU 275
    WM_KEYDOWN                  EQU 256
    WM_ERASEBACKGROUND          EQU 014h
    VK_W                        EQU 110001h
    VK_A                        EQU 1E0001h
    VK_S                        EQU 1F0001h
    VK_D                        EQU 200001h
    SND_ASYNC                   EQU 1

                                ; Tetromino shape definitions
    TETRO_0                     db  2, 4, "x x x xx"     ; L
    TETRO_1                     db  2, 4, " x x xxx"     ; Reverse L
    TETRO_2                     db  2, 2, "xxxx"         ; Block
    TETRO_3                     db  4, 1, "xxxx"         ; Line
    TETRO_4                     db  3, 2, " xxxx "       ; snake from BL to TR
    TETRO_5                     db  3, 2, "xx  xx"       ; snake from TR to BL
    TETRO_6                     db  3, 2, " x xxx"       ; penith
    
    poolStart:
    TETRO_SHAPE_POOL            dq TETRO_0, TETRO_1, TETRO_2, TETRO_3, TETRO_4, TETRO_5, TETRO_6
                                ; Tetromino shape pool
    TETRO_SHAPE_POOL_SIZE       EQU ($-poolStart)/8
    TETRO_MAX_WIDTH             EQU 4
    TETRO_MAX_HEIGHT            EQU 4
    TETRO_BUFFER_SIZE           EQU TETRO_MAX_WIDTH * TETRO_MAX_HEIGHT

.data?                          ; --------------------------
    moduleHandle                dq  ?
    hwndWindow                  dq  ?
    msg                         db  48                  dup(?)
    playField                   db  GRID_BYTE_SIZE      dup(?)
    tetroBuffer                 db  TETRO_BUFFER_SIZE   dup(?)
    tetroBufferRotateTmp        db  TETRO_BUFFER_SIZE   dup(?)
    tetroBufferCurrentWidth     db  ?
    tetroBufferCurrentHeight    db  ?
    playerPosX                  db  ?
    playerPosY                  db  ?
    hdc                         dq  ?
    rndSeed                     dq  ?
    skipNextGL                  db  ?
    
.code                           ; --------------------------

main PROC 
    call InitRandom

    push rbp
    mov rbp, rsp
    sub rsp, 120h

   ; mov rax, OFFSET TETRO_0
    ;mov qword ptr [TETRO_SHAPE_POOL], rax

    call InitPlayField

    call LoadRandomTetromino

    mov rcx, 0
    mov rdx, 0
    call GetTetroState
    mov rcx, 1
    mov rdx, 0
    call GetTetroState


    mov byte ptr [playerPosX], 0
    mov byte ptr [playerPosY], 0

   
    ; Get Module handle
    mov rax, GetModuleHandleA(0) 
    mov [moduleHandle], rax

    ; Set instance handle
    mov rax, [moduleHandle]
    mov [wndClass_hInstance], rax

    ; Set the class name
    lea rax, myClassName
    mov [wndClass_className], rax

    lea rax, Offset WndProc
    mov qword ptr [wndClass_wndProc], rax

    ; Register the window class
    mov rcx, wndClass_start
    call RegisterClassA
    test rax, rax
    jz fail
    
    mov r11, BLOCK_PIXEL_LENGTH
    mov rax, GRID_SIZE_X
    mul r11
    mov r12, rax
    mov rax, GRID_SIZE_Y
    mul r11
    mov r13, rax
    add r13, 12
   
    ; Create Window
    xor ecx, ecx                                ; dwExStyle
    lea rdx, OFFSET myClassName                 ; lpClassName
    lea r8, OFFSET myWindowTitle                ; lpWindowName
    mov r9d, WS_SYSMENU                         ; dwStyle
    mov dword ptr [rsp + 32], CW_USEDEFAULT     ; X
    mov dword ptr [rsp + 40], CW_USEDEFAULT     ; Y
    mov dword ptr [rsp + 48], r12d              ; nWidth
    mov dword ptr [rsp + 56], r13d              ; nHeight
    mov qword ptr [rsp + 64], 0                 ; hWndParent
    mov qword ptr [rsp + 72], 0                 ; hMenu
    mov rax, qword ptr [moduleHandle]
    mov qword ptr [rsp + 80], rax               ; hInstance
    mov qword ptr [rsp + 88], 0                 ; lpParam
 
    call CreateWindowExA

    mov [hwndWindow], rax
    test rax, rax
    jz fail

    ; Show the window
    mov rcx, [hwndWindow]
    mov rdx, 5
    call ShowWindow

    ; Enter the message loop
message_loop:
    ; Get Message
    lea rcx, msg
    mov rdx, 0
    mov r8, 0
    mov r9, 0
    call GetMessageA
    cmp rax, 1
    jne message_loop_break
    ; Translate Message
    lea rcx, msg
    call TranslateMessage
    ; Dispatch Message
    lea rcx, msg
    call DispatchMessageA

    jmp message_loop

message_loop_break:
    mov rcx, 0
    call ExitProcess

fail:
    call GetLastError
    mov rcx, 1
    call ExitProcess

    mov rsp, rbp
    pop rbp
main ENDP

InitPlayField PROC
    push rbx 
    lea rax, playField
    lea rbx, [playField + GRID_BYTE_SIZE]
_loop:
    mov byte ptr [rax], 0  
    inc rax
    cmp rax, rbx
    je _loop_break
    jmp _loop
_loop_break:
    pop rbx
    ret
InitPlayField ENDP

; (out) rax Start Seed
InitRandom PROC
    call GetTickCount
    mov [rndSeed], rax
    ret
InitRandom ENDP

; (out) rax random
Random64 PROC
   push rbx
   mov rax, [rndSeed]
   add rax, 12h
   rol rax, 12
   xor rax, [rndSeed]
   mov rbx, 41C64E6Dh
   mul rbx
   ror rax, 8
   mov [rndSeed], rax
   pop rbx
   ret
Random64 ENDP

; (in)  rcx min
; (in)  rdx max
; (out) rax random
RandomRange PROC
    push r8
    mov r8, rcx         ; min
    push r9 
    mov r9, rdx         ; max   
    push r10
    mov r10, r9
    sub r10, r8         ; interval
    push rdx

    call Random64 
   
    xor rdx, rdx
    div r10

    mov rax, rdx
    add rax, r8

    pop rdx
    pop r10
    pop r9
    pop r8
    ret
RandomRange ENDP

LoadRandomTetromino PROC
    push rcx
    push rdx
    mov rcx, 0
    mov rdx, TETRO_SHAPE_POOL_SIZE
    call RandomRange
    mov rcx, rax
    call LoadTetromino
    pop rdx
    pop rcx
    ret
LoadRandomTetromino ENDP

; (in) rcx tetro index
LoadTetromino PROC
    call ClearTetroBuffer

    push r8
    push rax
    push rdx
    ; Calculate offset address
    mov rax, rcx
    mov r8, 8
    mul r8                              ; rax = rcx * 8

    lea r8, TETRO_SHAPE_POOL  ; 
    add r8, rax                         ; r8 = (byte*)TETRO_SHAPE_POOL[rcx]
    mov r8, [r8]
    ; r8 now points to the desired tetromino
    ; Layout (byte array):
    ;   [0]                     tetro width
    ;   [1]                     tetro height
    ;   [2..(width * height)]   tetromino data  

    ; r8 -> [0] tetro width
    mov al, byte ptr [r8]
    mov [tetroBufferCurrentWidth], al
    inc r8
    
    ; r8 -> [1] tetro height
    mov al, byte ptr [r8]
    mov [tetroBufferCurrentHeight], al
    inc r8

    ; r8 -> [2] tetromino data 

    push r10                                        ; x = 0
    push r11                                        ; y = 0
    xor r10, r10
    xor r11, r11

    push r12    
    push r13
    xor r12, r12
    xor r13, r13
    mov r12b, byte ptr [tetroBufferCurrentWidth]    ; maxX
    mov r13b, byte ptr [tetroBufferCurrentHeight]   ; maxY
    push r14
    push r15

_loopY:
    cmp r11b, r13b
    je _loopY_break
    xor r10b, r10b                                    ; x = 0

_loopX:
    cmp r10b, r12b
    je _loopX_break
    
    ; Calculate read address
    
    push rax
    mov rax, r11                                      ; <- y
    mul r12
    add rax, r10
    add rax, r8
    mov r14b, byte ptr [rax]
    
    pop rax

    ; -> r14b now contains the read state
    cmp r14b, 'x'
    jne _loopX_continue
    
    push rcx
    push rdx
    push r8
    mov rcx, r10
    mov rdx, r11
    mov r8, 1
    call SetTetroState
    pop r8
    pop rdx
    pop rcx


_loopX_continue:
    inc r10b
    jmp _loopX

_loopX_break:
_loopY_continue:
    inc r11b
    jmp _loopY

_loopY_break:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10

    pop rdx
    pop rax
    pop r8
    ret
LoadTetromino ENDP

ClearTetroBuffer PROC
    push rbx 
    lea rax, tetroBuffer
    lea rbx, [tetroBuffer + TETRO_BUFFER_SIZE]
_loop:
    mov byte ptr [rax], 0  
    inc rax
    cmp rax, rbx
    je _loop_break
    jmp _loop
_loop_break:
    pop rbx
    ret
ClearTetroBuffer ENDP

ClearTetroRotateBuffer PROC
    push rbx 
    lea rax, tetroBufferRotateTmp
    lea rbx, [tetroBufferRotateTmp + TETRO_BUFFER_SIZE]
_loop:
    mov byte ptr [rax], 0  
    inc rax
    cmp rax, rbx
    je _loop_break
    jmp _loop
_loop_break:
    pop rbx
    ret
ClearTetroRotateBuffer ENDP

CopyTetroTmpToActual PROC
    push rcx
    xor rcx, rcx                    ; i = 0
    push rdx
    mov rdx, TETRO_BUFFER_SIZE      ; maxI = TBUFSIZE
    push r8                         ; tmpChar
    push r9                         ; tmpAddr
   
_loop:
    cmp rcx, rdx
    je loop_break

   ; lea r8, byte ptr [tetroBuffer + rcx]
    lea r9, tetroBufferRotateTmp
    add r9, rcx
    mov r8b, byte ptr [r9]

    lea r9, tetroBuffer
    add r9, rcx
    mov byte ptr [r9], r8b

    inc rcx
    jmp _loop

loop_break:
    pop r9
    pop r8
    pop rdx
    pop rcx
    ret
CopyTetroTmpToActual ENDP

ClearScreen PROC
    LOCAL bgBrush: QWORD
    LOCAL rectToInvalidate: RECT

    enter 32, 0
    push rcx
    push rdx

    mov rcx, 00220202h
    call CreateSolidBrush
    mov bgBrush, rax
     
    ; Get area to fill
    mov rcx, [hwndWindow]
    lea rdx, rectToInvalidate
    call GetClientRect

    mov rcx, [hdc]
    lea rdx, rectToInvalidate
    mov r8, bgBrush
    call FillRect

    ; Destroy brush
    mov rcx, bgBrush
    call DeleteObject

    pop rdx
    pop rcx
    leave
    ret
ClearScreen ENDP

; Rotates the currently selected tetromino (in tetroBuffer) Clockwise
RotateTetroCW PROC
    push rcx
    push rdx
    xor rcx, rcx                ; x = 0
    xor rdx, rdx                ; y = 0
    push r8
    push r9
    mov r8, TETRO_MAX_WIDTH     ; maxWidth
    mov r9, TETRO_MAX_HEIGHT    ; maxHeight
    push r10                    ; readX
    push r11                    ; readY
    push r12                    ; tmpChar
    push r13
    push r14
    xor r13, r13
    xor r14, r14
    mov r13b, [tetroBufferCurrentWidth]
    mov r14b, [tetroBufferCurrentHeight]
    
    call ClearTetroRotateBuffer

y_loop:
    cmp rdx, r9
    je y_loop_break
    xor rcx, rcx                ; x = 0
x_loop:
    cmp rcx, r8
    je x_loop_break

    ; putX = rcx
    ; putY = rdx
    ; Calculate ReadX, ReadY
    mov r10, rdx                ; readX = putY

    mov r11, r14                 ; readY = maxHeight
    dec r11                     ; --readY
    sub r11, rcx                ; readY -= putX

    ; readX = r10
    ; readY = r11

    ; Retrieve Read state
    push rcx
    push rdx
    mov rcx, r10
    mov rdx, r11
    call GetTetroState
    mov r12, rax

    pop rdx
    pop rcx

    ; Set new state
    push r8
    mov r8, r12
    call SetTetroTmpState
    pop r8

    inc rcx
    jmp x_loop

y_loop_continue:
x_loop_break:
    inc rdx
    jmp y_loop

y_loop_break:

    mov byte ptr [tetroBufferCurrentWidth], r14b    ; swap x and y
    mov byte ptr [tetroBufferCurrentHeight], r13b

    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx

    ; copy tmpRotateBuffer to tetro buffer
    call CopyTetroTmpToActual

    ret
RotateTetroCW ENDP

RotateTetroCCW PROC
    call RotateTetroCW
    call RotateTetroCW
    call RotateTetroCW
    ret
RotateTetroCCW ENDP

; (in) rcx X
; (in) rdx Y
GetTetroState PROC
    push r8
    push rdx
    mov r8, TETRO_MAX_WIDTH

    mov rax, rdx
    mul r8
    add rax, rcx
    
    lea r8, tetroBuffer
    add rax, r8
    
    mov r8b, byte ptr [rax]
    xor rax, rax
    mov al, r8b

    pop rdx
    pop r8
    ret
GetTetroState ENDP

; (in) rcx X
; (in) rdx Y
; (in) r8 state
SetTetroState PROC
    push r8
    push rdx
    mov r8, TETRO_MAX_WIDTH

    mov rax, rdx            ; rax = Y
    mul r8                  ; rax *= GRID_SIZE_X
    add rax, rcx            ; rax += X
    
    lea r8, tetroBuffer       ; 
    add rax, r8             ; rax += &playField

    pop rdx
    pop r8
    mov byte ptr [rax], r8b

    ret
SetTetroState ENDP

SetTetroTmpState PROC
    push r8
    push rdx
    mov r8, TETRO_MAX_WIDTH

    mov rax, rdx            ; rax = Y
    mul r8                  ; rax *= GRID_SIZE_X
    add rax, rcx            ; rax += X
    
    lea r8, tetroBufferRotateTmp 
    add rax, r8             ; rax += &playField

    pop rdx
    pop r8
    mov byte ptr [rax], r8b

    ret
SetTetroTmpState ENDP

; (in) rcx X
; (in) rdx Y
GetFieldState PROC
    push r8
    push rdx
    mov r8, GRID_SIZE_Y
    cmp rdx, r8
    jge false_oob
    mov r8, GRID_SIZE_X
    cmp rcx, r8
    jge false_oob

    mov rax, rdx
    mul r8
    add rax, rcx
    
    lea r8, playField
    add rax, r8
    
    mov r8b, byte ptr [rax]
    xor rax, rax
    mov al, r8b

    pop rdx
    pop r8
    ret
false_oob:
    xor rax, rax
    pop rdx
    pop r8
    ret
GetFieldState ENDP

; (in) rcx X
; (in) rdx Y
; (in) r8 state
SetFieldState PROC
    push r8
    push rdx
    mov r8, GRID_SIZE_X

    mov rax, rdx            ; rax = Y
    mul r8                  ; rax *= GRID_SIZE_X
    add rax, rcx            ; rax += X
    
    lea r8, playField       ; 
    add rax, r8             ; rax += &playField

    pop rdx
    pop r8
    mov byte ptr [rax], r8b

    ret
SetFieldState ENDP

; (in) rcx x
; (in) rdx y
; (in) r8 color
RenderBlock PROC
    LOCAL blockRect: RECT
    LOCAL blockBrush: QWORD

    push rcx
    push rdx
    push r8
    mov r8, BLOCK_PIXEL_LENGTH


    ; Scale coordinates with PIXEL_LENGTH
    push rdx

    mov rax, rcx
    mul r8
    mov rcx, rax

    pop rdx

    mov rax, rdx
    mul r8
    mov rdx, rax

    ; Setup rect with scaled coordinates
    mov dword ptr blockRect.left, ecx
    add ecx, BLOCK_PIXEL_LENGTH
    mov dword ptr blockRect.right, ecx

    mov dword ptr blockRect.top, edx
    add edx, BLOCK_PIXEL_LENGTH
    mov dword ptr blockRect.bottom, edx

    ; Create brush
    pop r8                  ; restore original color
    mov rcx, r8
    push r9
    
    sub rsp, 32 + 8         
    call CreateSolidBrush

    mov blockBrush, rax

    mov rcx, [hdc]
    lea rdx, blockRect
    mov r8, blockBrush
    
    call FillRect  

    ; Destroy brush
    mov rcx, blockBrush

    call DeleteObject
    add rsp, 32 + 8
    pop r9

    pop rdx
    pop rcx
    ret
RenderBlock ENDP

; (in) rcx row index
CheckIfRowFull PROC
    push rdx
    xor rdx, rdx
    push r8
    xor r8, r8
    mov r8b, byte ptr [GRID_SIZE_X]

_loop:
    cmp rdx, r8
    je _loop_break_true

    push rcx
    push rdx
    mov rdx, rcx
    mov rcx, r8        
    call GetFieldState
    pop rdx
    pop rcx
    test rax, rax
    jz _loop_break_false

    jmp _loop

_loop_break_false:
    mov rax, 0
    jmp _loop_break

_loop_break_true:
    mov rax, 1
_loop_break:
    pop r8
    pop rdx

    ret
CheckIfRowFull ENDP

; (in) rcx row to clear
ClearAndMoveDown PROC

    ret
ClearAndMoveDown ENDP

CheckRowClear PROC
    push rcx
    mov rcx, GRID_SIZE_Y - 1        ; row index
    

    pop rdx
    ret
CheckRowClear ENDP

RenderPlayerField PROC
    push rcx
    push rdx
    xor rcx, rcx            ; x = 0
    xor rdx, rdx            ; y = 0
    push r8
    push r9
    mov r8, GRID_SIZE_X     ; maxX
    mov r9, GRID_SIZE_Y     ; maxY
    push r10
    push r11

    ; outer Y loop
loop_y:
    cmp rdx, r9
    je loop_y_break

    xor rcx, rcx
    ; do x loop
loop_x:
    cmp rcx, r8
    je loop_x_break

    call GetFieldState
    cmp al, 1          ; Set field;
    je draw_single_block

    jmp loop_x_continue

draw_single_block:
    push r8
    mov r8, 00FF0000h
    call RenderBlock
    pop r8
    jmp loop_x_continue

loop_x_continue:
    inc rcx
    jmp loop_x
loop_x_break:
    inc rdx
    jmp loop_y

loop_y_break:
    
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx

    ret
RenderPlayerField ENDP

RenderPlayer PROC
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    xor rax, rax                                    ; x
    xor rbx, rbx                                    ; y
    xor rcx, rcx
    mov cl, byte ptr [tetroBufferCurrentWidth]      ; maxX
    xor rdx, rdx
    mov dl, byte ptr [tetroBufferCurrentHeight]     ; maxY
    xor r8, r8
    mov r8b, byte ptr [playerPosX]                   ; playerX
    xor r9, r9
    mov r9b, byte ptr [playerPosY]                   ; playerY

_loopY:
    cmp bl, dl                                      ; if (y == maxY)
    je _loopY_break

_loopX:
    cmp al, cl                                      ; if (x == maxX)
    je _loopX_break
    ; inner loop body

    ; check if player tetro block is set
    
    push rcx
    push rdx
    mov rcx, rax
    mov rdx, rbx
    push rax
    call GetTetroState
    mov r10, rax
    pop rax
    pop rdx
    pop rcx

    ; tetro state is now in r10
    test r10, r10
    jz _loopX_continue

    push rcx
    push rdx
    mov rcx, rax
    add rcx, r8
    mov rdx, rbx
    add rdx, r9
    push r8
    mov r8, 000000FFh         ; Todo state to color
    push rax
    call RenderBlock
    pop rax
    pop r8

    pop rdx
    pop rcx

_loopX_continue:
    inc al
    jmp _loopX

_loopX_break:
_loopY_continue:
    inc bl
    xor rax, rax
    jmp _loopY

_loopY_break:

    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
RenderPlayer ENDP

GameUpdate PROC
    call MovePlayerDown
    ret
GameUpdate ENDP

GamePaint PROC
    LOCAL ps: QWORD

    sub rsp, 72
    mov ps, rsp

    mov rcx, hwndWindow
    mov rdx, ps
    call BeginPaint
    mov [hdc], rax

    call ClearScreen

    call RenderPlayerField

    call RenderPlayer



    mov rcx, [hwndWindow]
    mov rdx, ps 
    call EndPaint

    add rsp, 72

    ret
GamePaint ENDP

RequestPaint PROC
    push rcx
    push rdx
    push r8
    mov rcx, [hwndWindow]
    mov rdx, 0
    mov r8, 0
    call InvalidateRect
    pop r8
    pop rdx
    pop rcx
    ret
RequestPaint ENDP

IsPlayerJammedInPlayfield PROC
    xor rax, rax
    push rcx
    push rdx
    ;xor rcx, rcx                        ; x = 0
    xor rdx, rdx                        ; y = 0
    push r8                 
    push r9                     
    mov r8b, [tetroBufferCurrentWidth]  ; maxX
    mov r9b, [tetroBufferCurrentHeight] ; maxY

loopY:
    cmp dl, r9b                         ; if(y == maxY)
    je loopY_break
    xor rcx, rcx
loopX:
    cmp cl, r8b                         ; if(x == maxX)
    je loopX_break

    call GetTetroState
    test rax, rax
    jz loopX_continue
    ; check if there is a block in playfield at [x + playerPosX, y + playerPosY]
    ; if yes, do loopY_break and set rax to 1

    add cl, byte ptr [playerPosX]
    add dl, byte ptr [playerPosY]
    call GetFieldState
    test rax, rax
    jz noEarlyReturn
    mov rax, 1
    jmp loopY_break

noEarlyReturn:
    sub cl, byte ptr [playerPosX]
    sub dl, byte ptr [playerPosY]

loopX_continue:
    inc cl
    jmp loopX
loopX_break:
loopY_continue:
    inc dl
    jmp loopY
loopY_break:
    
    
    pop r9
    pop r8
    pop rdx
    pop rcx
    ret
IsPlayerJammedInPlayfield ENDP

IsPlayerJammedInBounds PROC
    mov rax, 0
    push rcx
    push rbx
    mov bl, byte ptr [playerPosX]
    cmp bl, -1
    jle return_true

    mov rcx, GRID_SIZE_X
    sub cl, byte ptr [tetroBufferCurrentWidth]
    cmp bl, cl
    jge return_true

    mov bl, byte ptr [playerPosY]
    mov rcx, GRID_SIZE_Y
    sub cl, byte ptr [tetroBufferCurrentHeight]
    cmp bl, cl
    jge return_true


    jmp return_false
    
return_true:
    mov rax, 1
return_false:
    pop rbx
    pop rcx
    ret ; todo
IsPlayerJammedInBounds ENDP

IsPlayerJammed PROC
    mov rax, 0

    call IsPlayerJammedInPlayfield
    test rax, rax
    jnz ret_true

    call IsPlayerJammedInBounds
    ret

ret_true:
    mov rax, 1
ret_false:
    ret
IsPlayerJammed ENDP

CommitToPlayField PROC
    push rcx
    push rdx
    ;xor rcx, rcx                       ; x = 0
    xor rdx, rdx                        ; y = 0
    push r8                 
    push r9                     
    mov r8b, [tetroBufferCurrentWidth]  ; maxX
    mov r9b, [tetroBufferCurrentHeight] ; maxY

loopY:
    cmp dl, r9b                         ; if(y == maxY)
    je loopY_break
    xor rcx, rcx
loopX:
    cmp cl, r8b                         ; if(x == maxX)
    je loopX_break

    call GetTetroState
    test rax, rax
    jz loopX_continue
    ; set block

    add cl, byte ptr [playerPosX]
    add dl, byte ptr [playerPosY]
    push r8
    mov r8, 1
    call SetFieldState
    pop r8
    sub dl, byte ptr [playerPosY]
    sub cl, byte ptr [playerPosX]

loopX_continue:
    inc cl
    jmp loopX
loopX_break:
loopY_continue:
    inc dl
    jmp loopY
loopY_break:
    
    
    pop r9
    pop r8
    pop rdx
    pop rcx

    call CheckRowClear
    ret
CommitToPlayField ENDP

MovePlayerDown PROC
    inc [playerPosY]
    call IsPlayerJammed
    test rax, rax
    jz cleanup
    ; Player is jammed 
    ; Undo and commit
    dec [playerPosY]
    call CommitToPlayField
    ; Reset player position and new tetro
    mov byte ptr [playerPosY], 0
    call LoadRandomTetromino
   
decollide_loop:
    call IsPlayerJammed
    test rax, rax
    jz decollide_break
    dec [playerPosX]
    jmp decollide_loop

decollide_break:
cleanup:
    ret
MovePlayerDown ENDP

TryRotateCCW PROC
    call RotateTetroCCW
    call IsPlayerJammed
    test rax, rax
    jz doReturn
    call RotateTetroCW

doReturn:
    ret
TryRotateCCW ENDP

; (in) rcx keycode
OnKeyDown PROC
    and ecx, 00FFFFFFh  ; Remove repeat-count
    
    cmp ecx, VK_W
    je rotateCCW
    cmp ecx, VK_S
    je goDown
    cmp ecx, VK_A
    je goLeft
    cmp ecx, VK_D
    je goRight

    jmp cleanup

goLeft:
    dec [playerPosX]
    call IsPlayerJammed
    test rax, rax
    jz goLeft_cleanup
    inc [playerPosX]
goLeft_cleanup:
    call RequestPaint
    jmp cleanup

goRight:
    inc [playerPosX]
    call IsPlayerJammed
    test rax, rax
    jz goRight_cleanup
    dec [playerPosX]

goRight_cleanup:
    call RequestPaint
    jmp cleanup
rotateCCW:
    call TryRotateCCW
    call RequestPaint
    jmp cleanup
goDown:
    call MovePlayerDown
    mov byte ptr [skipNextGL], 1
    call RequestPaint
    jmp cleanup

cleanup:
    ret
OnKeyDown ENDP

; (in)  rcx hWnd
; (in)  edx uMsg
; (in)  r9 wParam
; (in)  r10 lParam
; (out) rax LRESULT
WndProc PROC
    enter 32, 0

    cmp edx, WM_CREATE
    je onWmCreate

    cmp edx, WM_TIMER
    je onWmTimer

    cmp edx, WM_PAINT
    je onWmPaint

    cmp edx, WM_KEYDOWN
    je onWmKeyDown

    cmp edx, WM_ERASEBACKGROUND
    je onWmEraseBackground

    cmp edx, WM_DESTROY
    je onWmDestroy

    sub rsp, 32
    call DefWindowProcA
    add rsp, 32
    jmp cleanup

onWmCreate:
    ; Create a timer for the game loop
    mov rdx, 1
    mov r8, 500
    mov r9, 0
    call SetTimer

    xor rax, rax
    jmp cleanup

onWmTimer:
    mov r12b, byte ptr [skipNextGL]
    test r12b, r12b
    jnz skipGameUpdate

    call GameUpdate
    mov rcx, [hwndWindow]
    mov rdx, 0
    mov r8, 0
    call InvalidateRect
skipGameUpdate:
    mov byte ptr [skipNextGL], 0

    xor rax, rax

    jmp cleanup

onWmPaint:
    call GamePaint
    jmp cleanup

onWmKeyDown:
    push rcx
    mov rcx, r9
    call OnKeyDown
    pop rcx
    jmp cleanup

onWmEraseBackground:
    mov rax, 1
    jmp cleanup

onWmDestroy:
    xor rcx, rcx
    call PostQuitMessage
    xor rax, rax

cleanup:
    leave
    ret

handle_destroy:
    mov rcx, 0
    call ExitProcess
    ret
WndProc ENDP

end
