; AWGUS low-level GF1 support
;
; Copyright (c) 2026 Nikos Papanagiotou and contributors
; SPDX-License-Identifier: MIT
;
; Adapted from PRE2GUS 1.3, Copyright (c) 2026 Nikos Papanagiotou and
; contributors, used under the MIT License.  No vendor SDK or game source was
; used.  This include deliberately leaves the board's analog mixer/interface
; registers untouched.

parse_ultrasnd:
    push es
    mov ax, [2ch]
    or ax, ax
    jz .fail
    mov es, ax
    xor di, di
.next_string:
    cmp byte [es:di], 0
    jne .compare
    cmp byte [es:di+1], 0
    je .fail
    inc di
    jmp .next_string
.compare:
    push di
    mov si, ultrasnd_key
    mov cx, 9
.compare_char:
    mov al, [es:di]
    cmp al, 'a'
    jb .already_upper
    cmp al, 'z'
    ja .already_upper
    sub al, 20h
.already_upper:
    cmp al, [si]
    jne .not_this
    inc di
    inc si
    loop .compare_char
    pop bx

    call parse_hex_component
    jc .fail
    mov [gus_base], ax
    call require_comma
    jc .fail
    call parse_dec_component
    jc .fail
    mov [gus_dma1], ax
    call require_comma
    jc .fail
    call parse_dec_component
    jc .fail
    mov [gus_dma2], ax
    call require_comma
    jc .fail
    call parse_dec_component
    jc .fail
    mov [gus_irq], ax
    call require_comma
    jc .fail
    call parse_dec_component
    jc .fail
    mov [gus_midi_irq], ax
    cmp byte [es:di], 0
    jne .fail

    mov ax, [gus_base]
    cmp ax, 210h
    jb .fail
    cmp ax, 260h
    ja .fail
    test al, 0fh
    jnz .fail
    mov bx, [gus_dma1]
    cmp bx, 7
    ja .fail
    cmp byte [dma_lut+bx], 0
    je .fail
    mov bx, [gus_dma2]
    cmp bx, 7
    ja .fail
    cmp byte [dma_lut+bx], 0
    je .fail
    mov bx, [gus_irq]
    cmp bx, 15
    ja .fail
    cmp byte [irq_lut+bx], 0
    je .fail
    mov bx, [gus_midi_irq]
    cmp bx, 15
    ja .fail
    cmp byte [irq_lut+bx], 0
    je .fail
    pop es
    clc
    ret
.not_this:
    pop di
.skip_string:
    cmp byte [es:di], 0
    je .past_string
    inc di
    jmp .skip_string
.past_string:
    inc di
    jmp .next_string
.fail:
    pop es
    stc
    ret

require_comma:
    cmp byte [es:di], ','
    jne .bad
    inc di
    clc
    ret
.bad:
    stc
    ret

parse_hex_component:
    xor bx, bx
    xor cx, cx
.loop:
    mov al, [es:di]
    cmp al, ','
    je .end
    or al, al
    jz .end
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .number
    and al, 0dfh
    cmp al, 'A'
    jb .bad
    cmp al, 'F'
    ja .bad
    sub al, 'A'-10
    jmp .add
.number:
    sub al, '0'
.add:
    shl bx, 4
    xor ah, ah
    add bx, ax
    inc di
    inc cx
    jmp .loop
.end:
    jcxz .bad
    mov ax, bx
    clc
    ret
.bad:
    stc
    ret

parse_dec_component:
    xor bx, bx
    xor cx, cx
.loop:
    mov al, [es:di]
    cmp al, ','
    je .end
    or al, al
    jz .end
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    sub al, '0'
    xor ah, ah
    push ax
    mov ax, bx
    mov dx, 10
    mul dx
    mov bx, ax
    pop ax
    add bx, ax
    inc di
    inc cx
    jmp .loop
.end:
    jcxz .bad
    mov ax, bx
    clc
    ret
.bad:
    stc
    ret

setup_gus_ports:
    mov ax, [gus_base]
    mov dx, ax
    add dx, 102h
    mov [gus_voice_port], dx
    inc dx
    mov [gus_command_port], dx
    inc dx
    mov [gus_data_low_port], dx
    inc dx
    mov [gus_data_high_port], dx
    mov dx, ax
    add dx, 006h
    mov [gus_status_port], dx
    mov dx, ax
    add dx, 107h
    mov [gus_dram_port], dx
    ret

; Reset the GF1 core and voices only.  No base-port mixer latch is written.
gus_reset:
    pushf
    cli
    mov dx, [gus_command_port]
    mov al, 4ch
    out dx, al
    mov dx, [gus_data_high_port]
    xor al, al
    out dx, al
    call gf1_delay
    call gf1_delay
    mov dx, [gus_command_port]
    mov al, 4ch
    out dx, al
    mov dx, [gus_data_high_port]
    mov al, 01h
    out dx, al
    call gf1_delay
    call gf1_delay

    mov dx, [gus_command_port]
    mov al, 41h
    out dx, al
    mov dx, [gus_data_high_port]
    xor al, al
    out dx, al
    mov dx, [gus_command_port]
    mov al, 45h
    out dx, al
    mov dx, [gus_data_high_port]
    xor al, al
    out dx, al
    mov dx, [gus_command_port]
    mov al, 49h
    out dx, al
    mov dx, [gus_data_high_port]
    xor al, al
    out dx, al

    mov dx, [gus_command_port]
    mov al, 0eh
    out dx, al
    mov dx, [gus_data_high_port]
    mov al, 0cdh                 ; 14 active voices -> 44.1 kHz GF1 rate
    out dx, al

    call gus_clear_pending
    xor si, si
.voice_loop:
    mov dx, [gus_voice_port]
    mov ax, si
    out dx, al
    mov dx, [gus_command_port]
    xor al, al
    out dx, al
    mov dx, [gus_data_high_port]
    mov al, 03h
    out dx, al
    mov dx, [gus_command_port]
    mov al, 0dh
    out dx, al
    mov dx, [gus_data_high_port]
    mov al, 03h
    out dx, al
    call gf1_delay
    mov dx, [gus_command_port]
    mov al, 09h
    out dx, al
    mov dx, [gus_data_low_port]
    xor ax, ax
    out dx, ax
    mov dx, [gus_command_port]
    mov al, 0ch
    out dx, al
    mov dx, [gus_data_high_port]
    mov al, 07h
    out dx, al
    inc si
    cmp si, 14
    jb .voice_loop

    call gus_clear_pending
    mov dx, [gus_command_port]
    mov al, 4ch
    out dx, al
    mov dx, [gus_data_high_port]
    mov al, 03h                  ; reset released + DAC; IRQ output disabled
    out dx, al
    popf
    ret

gus_clear_pending:
    push ax
    push dx
    mov dx, [gus_status_port]
    in al, dx
    mov dx, [gus_command_port]
    mov al, 41h
    out dx, al
    mov dx, [gus_data_high_port]
    in al, dx
    mov dx, [gus_command_port]
    mov al, 49h
    out dx, al
    mov dx, [gus_data_high_port]
    in al, dx
    mov dx, [gus_command_port]
    mov al, 8fh
    out dx, al
    mov dx, [gus_data_high_port]
    in al, dx
    pop dx
    pop ax
    ret

gf1_delay:
    push ax
    push cx
    push dx
    mov dx, [cs:gus_dram_port]
    mov cx, 7
.wait:
    in al, dx
    loop .wait
    pop dx
    pop cx
    pop ax
    ret

gus_probe:
    mov word [dram_addr_low], 0
    mov word [dram_addr_high], 0
    mov bl, 0aah
    call gus_poke
    mov word [dram_addr_low], 1
    mov bl, 055h
    call gus_poke
    mov word [dram_addr_low], 0
    call gus_peek
    cmp al, 0aah
    jne .fail
    mov word [dram_addr_low], 1
    call gus_peek
    cmp al, 055h
    jne .fail
    clc
    ret
.fail:
    stc
    ret

; Detect whether all four 256 KiB banks are independently writable.  Cards
; that do not pass use the first four 64 KiB cache slots only.
gus_detect_memory:
    mov word [dram_addr_low], 0
    mov word [dram_addr_high], 0
    mov bl, 011h
    call gus_poke
    mov word [dram_addr_high], 4
    mov bl, 022h
    call gus_poke
    mov word [dram_addr_high], 8
    mov bl, 033h
    call gus_poke
    mov word [dram_addr_high], 0ch
    mov bl, 044h
    call gus_poke
    mov byte [cache_slot_count], 4
    mov word [dram_addr_high], 0
    call gus_peek
    cmp al, 011h
    jne .done
    mov word [dram_addr_high], 4
    call gus_peek
    cmp al, 022h
    jne .done
    mov word [dram_addr_high], 8
    call gus_peek
    cmp al, 033h
    jne .done
    mov word [dram_addr_high], 0ch
    call gus_peek
    cmp al, 044h
    jne .done
    mov byte [cache_slot_count], 16
.done:
    ret

gus_poke:
    push ax
    push dx
    pushf
    cli
    mov dx, [cs:gus_command_port]
    mov al, 43h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, [cs:dram_addr_low]
    out dx, ax
    mov dx, [cs:gus_command_port]
    mov al, 44h
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov ax, [cs:dram_addr_high]
    out dx, al
    mov dx, [cs:gus_dram_port]
    mov al, bl
    out dx, al
    popf
    pop dx
    pop ax
    ret

gus_peek:
    push dx
    pushf
    cli
    mov dx, [cs:gus_command_port]
    mov al, 43h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, [cs:dram_addr_low]
    out dx, ax
    mov dx, [cs:gus_command_port]
    mov al, 44h
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov ax, [cs:dram_addr_high]
    out dx, al
    mov dx, [cs:gus_dram_port]
    in al, dx
    mov [cs:peek_value], al
    popf
    pop dx
    mov al, [cs:peek_value]
    ret

; DS:SI = bytes, CX = count.  The DRAM address is advanced by count.
gus_upload:
    push ax
    push bx
    push cx
    push dx
    push si
    pushf
    cli
    mov dx, [cs:gus_command_port]
    mov al, 44h
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov ax, [cs:dram_addr_high]
    out dx, al
.byte:
    mov dx, [cs:gus_command_port]
    mov al, 43h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, [cs:dram_addr_low]
    out dx, ax
    mov dx, [cs:gus_dram_port]
    lodsb
    out dx, al
    inc word [cs:dram_addr_low]
    jnz .next
    inc word [cs:dram_addr_high]
    mov dx, [cs:gus_command_port]
    mov al, 44h
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov ax, [cs:dram_addr_high]
    out dx, al
.next:
    loop .byte
    popf
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

gf1_start_voice:
    pushf
    cli
    push ax
    push bx
    push cx
    push dx
    mov dx, [cs:gus_voice_port]
    mov al, [cs:voice_number]
    out dx, al
    mov dx, [cs:gus_command_port]
    mov al, 0dh
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov al, 03h
    out dx, al
    call gf1_delay
    out dx, al
    mov dx, [cs:gus_command_port]
    xor al, al
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov al, 03h
    out dx, al
    call gf1_delay
    out dx, al
    mov dx, [cs:gus_command_port]
    mov al, 09h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    xor ax, ax
    out dx, ax

    mov byte [cs:voice_addr_register], 0ah
    mov ax, [cs:voice_begin_low]
    mov [cs:voice_addr_low], ax
    mov ax, [cs:voice_begin_high]
    mov [cs:voice_addr_high], ax
    call gf1_write_voice_address
    mov byte [cs:voice_addr_register], 02h
    mov ax, [cs:voice_loop_low]
    mov [cs:voice_addr_low], ax
    mov ax, [cs:voice_loop_high]
    mov [cs:voice_addr_high], ax
    call gf1_write_voice_address
    mov byte [cs:voice_addr_register], 04h
    mov ax, [cs:voice_end_low]
    mov [cs:voice_addr_low], ax
    mov ax, [cs:voice_end_high]
    mov [cs:voice_addr_high], ax
    call gf1_write_voice_address

    mov dx, [cs:gus_command_port]
    mov al, 01h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, [cs:voice_frequency]
    out dx, ax
    mov dx, [cs:gus_command_port]
    mov al, 0ch
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov al, [cs:voice_pan]
    out dx, al
    mov dx, [cs:gus_command_port]
    mov al, 09h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, [cs:voice_volume]
    out dx, ax
    mov dx, [cs:gus_command_port]
    xor al, al
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov al, [cs:voice_mode]
    and al, 0fch
    out dx, al
    call gf1_delay
    out dx, al
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    ret

gf1_write_voice_address:
    push ax
    push bx
    push cx
    push dx
    mov ax, [cs:voice_addr_low]
    mov cx, [cs:voice_addr_high]
    mov bx, cx
    shr ax, 7
    shr cx, 7
    shl bx, 9
    or ax, bx
    mov bx, ax
    mov dx, [cs:gus_command_port]
    mov al, [cs:voice_addr_register]
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, bx
    out dx, ax
    mov dx, [cs:gus_command_port]
    mov al, [cs:voice_addr_register]
    inc al
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, [cs:voice_addr_low]
    shl ax, 9
    out dx, ax
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; AL = voice, BX = frequency word.
gf1_voice_frequency:
    push ax
    push dx
    pushf
    cli
    mov dx, [cs:gus_voice_port]
    out dx, al
    mov dx, [cs:gus_command_port]
    mov al, 01h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, bx
    out dx, ax
    popf
    pop dx
    pop ax
    ret

; AL = voice, BX = GF1 current-volume word.
gf1_voice_volume:
    push ax
    push dx
    pushf
    cli
    mov dx, [cs:gus_voice_port]
    out dx, al
    mov dx, [cs:gus_command_port]
    mov al, 09h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    mov ax, bx
    out dx, ax
    popf
    pop dx
    pop ax
    ret

; AL = voice.  BX:CX = absolute DRAM address (high:low).
gf1_voice_current_address:
    push ax
    push dx
    pushf
    cli
    mov dx, [cs:gus_voice_port]
    out dx, al
    mov byte [cs:voice_addr_register], 0ah
    mov [cs:voice_addr_high], bx
    mov [cs:voice_addr_low], cx
    call gf1_write_voice_address
    popf
    pop dx
    pop ax
    ret

; AL = voice.
gf1_stop_voice:
    push ax
    push dx
    pushf
    cli
    mov dx, [cs:gus_voice_port]
    out dx, al
    mov dx, [cs:gus_command_port]
    mov al, 09h
    out dx, al
    mov dx, [cs:gus_data_low_port]
    xor ax, ax
    out dx, ax
    mov dx, [cs:gus_command_port]
    xor al, al
    out dx, al
    mov dx, [cs:gus_data_high_port]
    mov al, 03h
    out dx, al
    call gf1_delay
    out dx, al
    popf
    pop dx
    pop ax
    ret

gus_quiet:
    pushf
    cli
    push ax
    push si
    cmp word [cs:gus_base], 0
    je .done
    xor si, si
.voice:
    mov ax, si
    call gf1_stop_voice
    inc si
    cmp si, 14
    jb .voice
.done:
    pop si
    pop ax
    popf
    ret
