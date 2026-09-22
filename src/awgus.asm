; AWGUS - native GF1 hardware music and SFX launcher for Another World and
; Out of This World (DOS)
;
; Copyright (c) 2026 Nikos Papanagiotou and contributors
; SPDX-License-Identifier: MIT
;
; The original game is not included and is never modified on disk.  This
; launcher accepts exactly one independently identified executable, patches
; its materialized in-memory code, and preserves its original protection.
;
; Build: nasm -f bin -o AWGUS.COM src/awgus.asm

bits 16
cpu 386
org 100h

%ifdef TARGET_OOTW
%define APP_TAG              "OTWGUS"
%define GAME_BASENAME        "WORLD.EXE"
%define TARGET_SIZE          21316
%define TARGET_CRC32         006098240h

%define AW_SB_DETECT         03402h
%define AW_SB_START          034f0h
%define AW_SB_STOP           03501h
%define AW_MIX_ENTRY         03560h
%define AW_MIX_HOOK          0356ch
%define AW_MIX_DATA_SEG      0357dh
%define AW_SB_SINK_TEST      03727h
%define AW_SB_SINK           0372dh
%define AW_DISPATCH_TEST     03f10h
%define AW_DISPATCH          03f17h
%define AW_SFX_GUARD         03fd1h
%define AW_SFX_STOP_TEST     04030h
%define AW_SFX_STOP_EXIT     04040h
%define AW_SFX_COMMON_EXIT   04116h
%define AW_MUSIC_GUARD       0411ch
%define AW_MUSIC_STOP_TEST   04124h
%define AW_MUSIC_STOP_CALL   0412ch
%define AW_MIX_TAIL          03722h

%define AW_ACTIVE_MASK       0034eh
%define AW_MIX_WORK_SIZE     0051eh
%define AW_DEVICE_ACTIVE     00350h
%define AW_AUX_ACTIVE        0034fh
%define AW_SAMPLE_RATE       001a0h
%define AW_MIX_WORK_RESET    05b2eh
%define AW_RESOURCE_TABLE    0466ah

%define SUM_SB_DETECT        0d3c1h
%define SUM_SB_START         0a155h
%define SUM_DISPATCH         0519ch
%define SUM_SB_SINK          034e6h
%define SUM_MIX_ENTRY        08bf5h
%define SUM_SFX_GUARD        07b96h
%define SUM_MUSIC_GUARD      05e55h
%define SUM_SFX_STOP         00c51h
%define SUM_MUSIC_STOP       02f6fh
%else
%define APP_TAG              "AWGUS"
%define GAME_BASENAME        "ANOTHER.EXE"
%define TARGET_SIZE          20788
%define TARGET_CRC32         023726b6bh

%define AW_SB_DETECT         031e2h
%define AW_SB_START          032d0h
%define AW_SB_STOP           032e1h
%define AW_MIX_ENTRY         03340h
%define AW_MIX_HOOK          0334ch
%define AW_MIX_DATA_SEG      0335dh
%define AW_SB_SINK_TEST      03507h
%define AW_SB_SINK           0350dh
%define AW_DISPATCH_TEST     03cf0h
%define AW_DISPATCH          03cf7h
%define AW_SFX_GUARD         03d90h
%define AW_SFX_STOP_TEST     03dd6h
%define AW_SFX_STOP_EXIT     03de6h
%define AW_SFX_COMMON_EXIT   03eadh
%define AW_MUSIC_GUARD       03eb3h
%define AW_MUSIC_STOP_TEST   03ebbh
%define AW_MUSIC_STOP_CALL   03ec3h
%define AW_MIX_TAIL          03502h

%define AW_ACTIVE_MASK       00346h
%define AW_MIX_WORK_SIZE     00452h
%define AW_DEVICE_ACTIVE     00348h
%define AW_AUX_ACTIVE        00347h
%define AW_SAMPLE_RATE       00198h
%define AW_MIX_WORK_RESET    05a66h

%define SUM_SB_DETECT        02132h
%define SUM_SB_START         00b58h
%define SUM_DISPATCH         0050bh
%define SUM_SB_SINK          034e6h
%define SUM_MIX_ENTRY        005e5h
%define SUM_SFX_GUARD        0ff26h
%define SUM_MUSIC_GUARD      06545h
%define SUM_SFX_STOP         00c33h
%define SUM_MUSIC_STOP       0203dh
%endif

%define CACHE_MAX_SLOTS      16
%define CHANNEL_COUNT        4
%define IO_BUFFER_BYTES      512
%define SYNC_BATCH_TICKS     16
%define PRELOAD_MAX_SAMPLES  128
%define PRELOAD_LIMIT        000c0000h
%define WORK_BUFFER_PARAS    01000h
%define MEM_ENTRY_BYTES      20

    jmp start

start:
    cli
    mov ax, cs
    mov ss, ax
    mov sp, stack_top
    sti
    mov ds, ax
    mov es, ax
    cld
    mov [psp_segment], ax

    mov dx, msg_banner
    call print_dos
    call parse_command_line
    jc fatal_options
    call parse_ultrasnd
    jc fatal_config
    call setup_gus_ports
    call verify_game_file
    jc fatal_game

    ; Keep only the launcher, cache metadata, stack, and transfer buffer.
    mov bx, RESIDENT_PARAS
    mov ah, 4ah
    int 21h
    jc fatal_memory

    call gus_reset
    call gus_probe
    jc fatal_gus
    call gus_detect_memory
    mov dx, msg_preload_wait
    call print_dos
    call preload_all_sounds
    pushf
    mov dx, msg_preload_clear
    call print_dos
    popf
    jnc .preload_done
    mov dx, msg_preload_fallback
    call print_dos
    jmp .preload_reported
.preload_done:
    mov dx, msg_preload_ok
    call print_dos
.preload_reported:
    call install_vectors
    call exec_game
    mov [exec_error], ax
    mov byte [exec_failed], 0
    jnc .child_returned
    mov byte [exec_failed], 1
    jmp .after_child
.child_returned:
    mov ah, 4dh
    int 21h
    mov [child_exit_code], al
.after_child:
    call cleanup

    cmp byte [exec_failed], 0
    je .report_patch
    mov dx, msg_exec_failed
    call print_dos
    mov ax, [exec_error]
    call print_hex_word
    mov dx, msg_crlf
    call print_dos
    mov al, 1
    jmp exit_dos
.report_patch:
    cmp byte [patch_installed], 1
    je .report_runtime
    mov dx, msg_patch_missing
    call print_dos
    mov al, 2
    jmp exit_dos
.report_runtime:
%ifdef AUDIO_INTEGRATION_TEST
    cmp word [mixer_ticks], 256
    jb .audio_test_failed
    cmp word [sync_batches], 1
    jb .audio_test_failed
    cmp word [voice_starts], 1
    jb .audio_test_failed
    cmp word [stop_sync_calls], 1
    jb .audio_test_failed
%ifdef TARGET_OOTW
    cmp byte [preload_ready], 1
    jne .audio_test_failed
    cmp byte [preload_count], 97
    jne .audio_test_failed
%endif
    jmp .audio_test_complete
.audio_test_failed:
    mov byte [runtime_error], 1
.audio_test_complete:
    call print_audio_test_status
%endif
    cmp byte [runtime_error], 0
    je .ok
    mov dx, msg_runtime_error
    call print_dos
    mov al, 3
    jmp exit_dos
.ok:
    mov dx, msg_patch_ok
    call print_dos
    xor al, al
exit_dos:
    mov ah, 4ch
    int 21h

fatal_config:
    mov dx, msg_bad_config
    jmp fatal_plain
fatal_options:
    mov dx, msg_bad_options
    jmp fatal_plain
fatal_game:
    mov dx, msg_bad_game
    jmp fatal_plain
fatal_memory:
    mov dx, msg_no_memory
    jmp fatal_plain
fatal_gus:
    call gus_quiet
    mov dx, msg_no_gus
fatal_plain:
    call print_dos
    mov ax, 4c01h
    int 21h

; Launcher-only command line.  The default is hard alternating pan:
; voice 0 left, 1 right, 2 left, 3 right.  /P:C centers all voices and
; /P:n,n,n,n accepts four GF1 pan values in the inclusive range 0..15.
parse_command_line:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    xor cx, cx
    mov cl, [80h]
    mov si, 81h
.leading_space:
    or cx, cx
    jz .ok
    mov al, [si]
    cmp al, ' '
    je .consume_leading
    cmp al, 9
    jne .option
.consume_leading:
    inc si
    dec cx
    jmp .leading_space
.option:
    cmp al, '/'
    je .option_letter
    cmp al, '-'
    jne .bad
.option_letter:
    inc si
    dec cx
    or cx, cx
    jz .bad
    mov al, [si]
    inc si
    dec cx
    cmp al, '?'
    je .help
    and al, 0dfh
    cmp al, 'P'
    jne .bad
    or cx, cx
    jz .bad
    mov al, [si]
    inc si
    dec cx
    cmp al, ':'
    je .pan_argument
    cmp al, '='
    jne .bad
.pan_argument:
    or cx, cx
    jz .bad
    mov al, [si]
    and al, 0dfh
    cmp al, 'C'
    jne .pan_list
    inc si
    dec cx
    mov dword [pan_positions], 07070707h
    jmp .trailing_space

.pan_list:
    mov di, pan_positions
    mov bp, CHANNEL_COUNT
.pan_value:
    or cx, cx
    jz .bad
    mov al, [si]
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    xor bx, bx
.pan_digit:
    mov al, [si]
    cmp al, '0'
    jb .pan_value_done
    cmp al, '9'
    ja .pan_value_done
    mov dl, al
    sub dl, '0'
    mov ax, bx
    shl bx, 1
    shl ax, 3
    add bx, ax
    xor dh, dh
    add bx, dx
    cmp bx, 15
    ja .bad
    inc si
    dec cx
    jnz .pan_digit
.pan_value_done:
    mov [di], bl
    inc di
    dec bp
    jz .trailing_space
    or cx, cx
    jz .bad
    cmp byte [si], ','
    jne .bad
    inc si
    dec cx
    jmp .pan_value

.trailing_space:
    or cx, cx
    jz .ok
    mov al, [si]
    inc si
    dec cx
    cmp al, ' '
    je .trailing_space
    cmp al, 9
    je .trailing_space
    jmp .bad
.help:
    or cx, cx
    jz .show_help
.help_tail:
    mov al, [si]
    inc si
    dec cx
    cmp al, ' '
    je .help_more
    cmp al, 9
    jne .bad
.help_more:
    or cx, cx
    jz .show_help
    jmp .help_tail
.show_help:
    mov dx, msg_usage
    call print_dos
    mov ax, 4c00h
    int 21h
.ok:
    clc
    jmp .done
.bad:
    stc
.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

exec_game:
    push cs
    pop ds
    push cs
    pop es
    mov word [exec_params], 0
    mov ax, [psp_segment]
    mov word [exec_params+2], exec_tail
    mov word [exec_params+4], ax
    mov word [exec_params+6], 5ch
    mov word [exec_params+8], ax
    mov word [exec_params+10], 6ch
    mov word [exec_params+12], ax
    mov dx, game_filename
    mov bx, exec_params
    mov ax, 4b00h
    int 21h
    push cs
    pop ds
    ret

; Verify the exact packed executable before any in-memory patching.  CRC-32
; and length are compatibility identifiers; no bytes from the game are kept.
verify_game_file:
    mov dx, game_filename
    mov ax, 3d00h
    int 21h
    jc .fail
    mov [file_handle], ax
    mov bx, ax
    xor cx, cx
    xor dx, dx
    mov ax, 4202h
    int 21h
    jc .close_fail
    or dx, dx
    jnz .close_fail
    cmp ax, TARGET_SIZE
    jne .close_fail
    xor cx, cx
    xor dx, dx
    mov ax, 4200h
    int 21h
    jc .close_fail
    mov dword [file_crc32], 0ffffffffh
.read:
    mov bx, [file_handle]
    mov dx, io_buffer
    mov cx, IO_BUFFER_BYTES
    mov ah, 3fh
    int 21h
    jc .close_fail
    or ax, ax
    jz .finish
    mov cx, ax
    mov si, io_buffer
.byte:
    xor ebx, ebx
    mov bl, [si]
    inc si
    mov eax, [file_crc32]
    xor eax, ebx
    mov bp, 8
.bit:
    shr eax, 1
    jnc .next_bit
    xor eax, 0edb88320h
.next_bit:
    dec bp
    jnz .bit
    mov [file_crc32], eax
    loop .byte
    jmp .read
.finish:
    not dword [file_crc32]
    mov bx, [file_handle]
    mov ah, 3eh
    int 21h
    mov word [file_handle], 0ffffh
    cmp dword [file_crc32], TARGET_CRC32
    jne .fail
    clc
    ret
.close_fail:
    mov bx, [file_handle]
    mov ah, 3eh
    int 21h
    mov word [file_handle], 0ffffh
.fail:
    stc
    ret

; Preload every type-0 sound resource when a full 1 MiB GF1 is present.  The
; exact game's MEMLIST/BANK files remain external; only compact identity and
; address metadata is retained while the child runs.  Samples are packed into
; the first 768 KiB without crossing a 256 KiB GF1 bank.  The top 256 KiB stays
; available as a four-slot fallback cache for an unexpected runtime sample.
preload_all_sounds:
    mov byte [preload_ready], 0
    mov byte [preload_count], 0
    mov byte [cache_base_slot], 0
    mov dword [preload_next], 0
    mov word [memlist_handle], 0ffffh
    mov word [bank_handle], 0ffffh
    mov word [work_segment], 0
    mov byte [current_bank], 0ffh
    mov word [memlist_index], 0
    mov word [memlist_entries], 0
    cmp byte [cache_slot_count], CACHE_MAX_SLOTS
    jne .fail

    mov bx, WORK_BUFFER_PARAS
    mov ah, 48h
    int 21h
    jc .fail
    mov [work_segment], ax

    mov dx, memlist_filename
    mov ax, 3d00h
    int 21h
    jc .fail
    mov [memlist_handle], ax

.next_entry:
    mov bx, [memlist_handle]
    mov dx, mem_entry
    mov cx, MEM_ENTRY_BYTES
    mov ah, 3fh
    int 21h
    jc .fail
    cmp ax, MEM_ENTRY_BYTES
    jne .fail
    cmp byte [mem_entry], 0ffh
    je .complete
    cmp byte [mem_entry+1], 0
    jne .advance_entry

    mov ax, [mem_entry+14]
    xchg al, ah
    mov [resource_packed], ax
    mov ax, [mem_entry+18]
    xchg al, ah
    mov [resource_size], ax
    or ax, ax
    jz .advance_entry
    cmp ax, 0fff0h
    ja .fail
    mov dx, [resource_packed]
    or dx, dx
    jz .fail
    cmp dx, ax
    ja .fail
    cmp byte [mem_entry+7], 0
    je .fail

    call open_resource_bank
    jc .fail

    mov eax, [mem_entry+8]
    xchg al, ah
    ror eax, 16
    xchg al, ah
    mov dx, ax
    shr eax, 16
    mov cx, ax
    mov bx, [bank_handle]
    mov ax, 4200h
    int 21h
    jc .fail

    push ds
    mov ax, [cs:work_segment]
    mov ds, ax
    xor dx, dx
    mov cx, [cs:resource_packed]
    mov bx, [cs:bank_handle]
    mov ah, 3fh
    int 21h
    pop ds
    jc .fail
    cmp ax, [resource_packed]
    jne .fail

    mov ax, [resource_packed]
    cmp ax, [resource_size]
    je .resource_ready
    push ds
    mov ax, [cs:work_segment]
    mov ds, ax
    call bytekiller_unpack
    pop ds
    jc .fail

.resource_ready:
    push ds
    mov ax, [cs:work_segment]
    mov ds, ax
    call preload_resource_sample
    pop ds
    jc .fail
.advance_entry:
    inc word [memlist_index]
    jmp .next_entry

.complete:
    mov ax, [memlist_index]
    mov [memlist_entries], ax
    cmp byte [preload_count], 0
    je .fail
    cmp dword [preload_next], PRELOAD_LIMIT
    ja .fail
    mov byte [preload_ready], 1
    mov byte [cache_slot_count], 4
    mov byte [cache_base_slot], 12
    clc
    jmp .cleanup

.fail:
    mov byte [preload_ready], 0
    mov byte [preload_count], 0
    mov byte [cache_slot_count], CACHE_MAX_SLOTS
    mov byte [cache_base_slot], 0
    stc

.cleanup:
    pushf
    mov bx, [bank_handle]
    cmp bx, 0ffffh
    je .close_memlist
    mov ah, 3eh
    int 21h
    mov word [bank_handle], 0ffffh
.close_memlist:
    mov bx, [memlist_handle]
    cmp bx, 0ffffh
    je .free_buffer
    mov ah, 3eh
    int 21h
    mov word [memlist_handle], 0ffffh
.free_buffer:
    mov ax, [work_segment]
    or ax, ax
    jz .finished
    push es
    mov es, ax
    mov ah, 49h
    int 21h
    pop es
    mov word [work_segment], 0
.finished:
    popf
    ret

; Open the BANKxx file selected by mem_entry+7, retaining the current handle
; across adjacent resources from the same bank.
open_resource_bank:
    mov al, [mem_entry+7]
    cmp al, [current_bank]
    je .ok
    mov bx, [bank_handle]
    cmp bx, 0ffffh
    je .name
    mov ah, 3eh
    int 21h
    mov word [bank_handle], 0ffffh
.name:
    mov al, [mem_entry+7]
    mov ah, al
    shr al, 4
    call nibble_to_hex
    mov [bank_filename+4], al
    mov al, ah
    and al, 0fh
    call nibble_to_hex
    mov [bank_filename+5], al
    mov dx, bank_filename
    mov ax, 3d00h
    int 21h
    jc .fail
    mov [bank_handle], ax
    mov al, [mem_entry+7]
    mov [current_bank], al
.ok:
    clc
    ret
.fail:
    mov byte [current_bank], 0ffh
    stc
    ret

nibble_to_hex:
    and al, 0fh
    add al, '0'
    cmp al, '9'
    jbe .done
    add al, 'A'-'9'-1
.done:
    ret

; In-place ByteKiller decoder for one resource in the 64 KiB work segment.
; The bitstream, CRC, and output length are stored big-endian at the tail.
bytekiller_unpack:
    mov byte [cs:unpack_error], 0
    mov ax, [cs:resource_packed]
    cmp ax, 16
    jb .fail
    test al, 3
    jnz .fail
    mov si, ax
    sub si, 4
    call bk_read_be32
    test eax, 0ffff0000h
    jnz .fail
    cmp ax, [cs:resource_size]
    jne .fail
    mov [cs:unpack_left], ax
    dec ax
    mov [cs:unpack_dst], ax

    sub si, 4
    call bk_read_be32
    mov [cs:unpack_crc], eax
    sub si, 4
    call bk_read_be32
    mov [cs:unpack_bits], eax
    xor [cs:unpack_crc], eax
    sub si, 4
    mov [cs:unpack_src], si
    mov ax, [cs:resource_packed]
    sub ax, 12
    shr ax, 1
    shr ax, 1
    mov [cs:unpack_reload_count], ax

.decode:
    cmp word [cs:unpack_left], 0
    je .check
    call bk_next_bit
    jc .one
    call bk_next_bit
    jc .reference_two
    mov cl, 3
    xor dx, dx
    call bk_copy_literal
    jmp .decode
.reference_two:
    mov cl, 8
    mov bp, 2
    call bk_copy_reference
    jmp .decode
.one:
    mov cl, 2
    call bk_get_bits
    cmp ax, 3
    je .literal_long
    cmp ax, 2
    je .reference_long
    cmp ax, 1
    je .reference_four
    mov cl, 9
    mov bp, 3
    call bk_copy_reference
    jmp .decode
.reference_four:
    mov cl, 10
    mov bp, 4
    call bk_copy_reference
    jmp .decode
.reference_long:
    mov cl, 8
    call bk_get_bits
    inc ax
    mov bp, ax
    mov cl, 12
    call bk_copy_reference
    jmp .decode
.literal_long:
    mov cl, 8
    mov dx, 8
    call bk_copy_literal
    jmp .decode
.check:
    cmp byte [cs:unpack_error], 0
    jne .fail
    cmp dword [cs:unpack_crc], 0
    jne .fail
    clc
    ret
.fail:
    stc
    ret

bk_read_be32:
    mov eax, [si]
    xchg al, ah
    ror eax, 16
    xchg al, ah
    ret

; Return the next bit in carry.  A zero sentinel reloads the preceding dword.
bk_next_bit:
    mov eax, [cs:unpack_bits]
    shr eax, 1
    jz .reload
    mov [cs:unpack_bits], eax
    ret
.reload:
    cmp word [cs:unpack_reload_count], 0
    je .underflow
    dec word [cs:unpack_reload_count]
    mov si, [cs:unpack_src]
    call bk_read_be32
    sub word [cs:unpack_src], 4
    xor [cs:unpack_crc], eax
    mov dl, al
    and dl, 1
    shr eax, 1
    or eax, 080000000h
    mov [cs:unpack_bits], eax
    test dl, dl
    jz .zero
    stc
    ret
.zero:
    clc
    ret
.underflow:
    mov byte [cs:unpack_error], 1
    clc
    ret

; CL = bit count, AX = value.
bk_get_bits:
    push bx
    xor bx, bx
    xor ch, ch
.bit:
    shl bx, 1
    call bk_next_bit
    adc bx, 0
    loop .bit
    mov ax, bx
    pop bx
    ret

; CL = count-field width, DX = count base.
bk_copy_literal:
    push dx
    call bk_get_bits
    pop dx
    add ax, dx
    inc ax
    mov bp, ax
    call bk_clamp_count
.byte:
    or bp, bp
    jz .done
    mov cl, 8
    call bk_get_bits
    mov di, [cs:unpack_dst]
    mov [di], al
    dec di
    mov [cs:unpack_dst], di
    dec bp
    jmp .byte
.done:
    ret

; CL = offset-field width, BP = byte count.
bk_copy_reference:
    call bk_get_bits
    mov dx, ax
    call bk_clamp_count
.byte:
    or bp, bp
    jz .done
    mov di, [cs:unpack_dst]
    mov si, di
    add si, dx
    cmp si, [cs:resource_size]
    jae .bad
    mov al, [si]
    mov [di], al
    dec di
    mov [cs:unpack_dst], di
    dec bp
    jmp .byte
.bad:
    mov byte [cs:unpack_error], 1
    mov bp, 0
.done:
    ret

bk_clamp_count:
    cmp bp, [cs:unpack_left]
    jbe .subtract
    mov bp, [cs:unpack_left]
.subtract:
    sub [cs:unpack_left], bp
    ret

; DS is the temporary work segment containing one unpacked type-0 resource.
preload_resource_sample:
    mov ax, [0]
    xchg al, ah
    shl ax, 1
    jc .fail
    mov [cs:sample_intro], ax
    mov ax, [2]
    xchg al, ah
    shl ax, 1
    jc .fail
    mov [cs:sample_loop], ax
    add ax, [cs:sample_intro]
    jc .fail
    cmp ax, 2
    jb .fail
    cmp ax, 0fff8h
    ja .fail
    mov [cs:sample_total], ax
    mov dx, ax
    add dx, 8
    jc .fail
    cmp dx, [cs:resource_size]
    ja .fail
    cmp byte [cs:preload_count], PRELOAD_MAX_SAMPLES
    jae .fail

    mov ax, [8]
    mov [cs:sample_sig_a], ax
    mov bx, [cs:sample_total]
    shr bx, 1
    add bx, 8
    mov ax, [bx]
    mov [cs:sample_sig_b], ax
    mov bx, [cs:sample_total]
    add bx, 6
    mov ax, [bx]
    mov [cs:sample_sig_c], ax

    mov eax, [cs:preload_next]
    mov edx, eax
    and edx, 00003ffffh
    movzx ecx, word [cs:sample_total]
    add edx, ecx
    cmp edx, 000040000h
    jbe .bank_ready
    add eax, 00003ffffh
    and eax, 0fffc0000h
.bank_ready:
    mov [cs:sample_base], eax
    mov edx, eax
    add edx, ecx
    cmp edx, PRELOAD_LIMIT
    ja .fail
    inc edx
    and edx, 0fffffffeh
    mov [cs:preload_next], edx

    xor bx, bx
    mov bl, [cs:preload_count]
    mov ax, [cs:memlist_index]
    cmp ah, 0
    jne .fail
    mov dl, al
    mov [cs:preload_resource_id+bx], al
    xor dh, dh
    mov si, dx
    mov al, [cs:preload_count]
    mov [cs:resource_preload_index+si], al
    mov si, bx
    shl si, 1
    mov ax, [cs:sample_intro]
    mov [cs:preload_intro+si], ax
    mov ax, [cs:sample_loop]
    mov [cs:preload_loop+si], ax
    mov ax, [cs:sample_sig_a]
    mov [cs:preload_sig_a+si], ax
    mov ax, [cs:sample_sig_b]
    mov [cs:preload_sig_b+si], ax
    mov ax, [cs:sample_sig_c]
    mov [cs:preload_sig_c+si], ax
    mov eax, [cs:sample_base]
    mov [cs:preload_base_low+si], ax
    shr eax, 16
    mov [cs:preload_base_high+si], ax

    mov eax, [cs:sample_base]
    mov [cs:dram_addr_low], ax
    shr eax, 16
    mov [cs:dram_addr_high], ax
    mov si, 8
    mov cx, [cs:sample_total]
    call gus_upload
    inc byte [cs:preload_count]
    clc
    ret
.fail:
    stc
    ret

install_vectors:
    mov ax, 3521h
    int 21h
    mov [old_int21], bx
    mov [old_int21+2], es
    mov ax, 3501h
    int 21h
    mov [old_int01], bx
    mov [old_int01+2], es
    mov ax, 3560h
    int 21h
    mov [old_int60], bx
    mov [old_int60+2], es
    mov ax, 3561h
    int 21h
    mov [old_int61], bx
    mov [old_int61+2], es
    mov ax, 3562h
    int 21h
    mov [old_int62], bx
    mov [old_int62+2], es

    push ds
    push cs
    pop ds
    mov dx, int21_hook
    mov ax, 2521h
    int 21h
    mov dx, mixer_hook
    mov ax, 2560h
    int 21h
    mov dx, stop_sync_hook
    mov ax, 2561h
    int 21h
    mov dx, stop_all_hook
    mov ax, 2562h
    int 21h
    pop ds
    ret

cleanup:
    push cs
    pop ds
    call gus_quiet
    push ds
    lds dx, [old_int62]
    mov ax, 2562h
    int 21h
    pop ds
    push ds
    lds dx, [old_int61]
    mov ax, 2561h
    int 21h
    pop ds
    push ds
    lds dx, [old_int60]
    mov ax, 2560h
    int 21h
    pop ds
    push ds
    lds dx, [old_int01]
    mov ax, 2501h
    int 21h
    pop ds
    push ds
    lds dx, [old_int21]
    mov ax, 2521h
    int 21h
    pop ds
    push cs
    pop ds
    ret

; The executable remaps the current DOS handler to INT 1h during startup.
; Chaining to the saved DOS handler therefore works for both entry paths.
int21_hook:
    push bp
    mov bp, sp
    push ax
    mov ax, [ss:bp+4]
    mov [cs:caller_cs], ax
    pop ax
    pop bp
    pushf
    cmp ah, 3dh
    jne .chain
    cmp byte [cs:patch_installed], 0
    jne .chain
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov si, dx
    mov di, config_name
.compare:
    mov al, [si]
    cmp al, 'a'
    jb .upper
    cmp al, 'z'
    ja .upper
    sub al, 20h
.upper:
    cmp al, [cs:di]
    jne .not_config
    inc si
    inc di
    cmp byte [cs:di], 0
    jne .compare
    cmp byte [si], 0
    jne .not_config
    call install_patch
.not_config:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.chain:
    popf
    jmp far [cs:old_int21]

install_patch:
    mov ax, [cs:caller_cs]
    mov es, ax
    mov [cs:game_cs], ax
    call verify_runtime
    jc .reject
    mov ax, [es:AW_MIX_DATA_SEG]
    mov [cs:game_ds], ax

    ; New instructions only.  The original bytes are neither stored nor
    ; restored; the child image disappears when the process exits.
    mov byte [es:AW_DISPATCH], 0e8h
    mov word [es:AW_DISPATCH+1], 0f83dh
    mov byte [es:AW_DISPATCH+3], 0c3h
    mov byte [es:AW_SB_DETECT], 031h
    mov byte [es:AW_SB_DETECT+1], 0c0h
    mov byte [es:AW_SB_DETECT+2], 0c3h
    mov byte [es:AW_SB_START], 0c3h
    mov byte [es:AW_SB_STOP], 0c3h
    mov byte [es:AW_MIX_HOOK], 0cdh
    mov byte [es:AW_MIX_HOOK+1], 060h
    mov byte [es:AW_SB_SINK], 0ebh
    mov byte [es:AW_SB_SINK+1], 011h
    mov byte [es:AW_SFX_GUARD], 0ebh
    mov byte [es:AW_SFX_GUARD+1], 008h
    mov byte [es:AW_MUSIC_GUARD], 0ebh
    mov byte [es:AW_MUSIC_GUARD+1], 006h
    mov byte [es:AW_SFX_STOP_EXIT], 0cdh
    mov byte [es:AW_SFX_STOP_EXIT+1], 061h
    mov byte [es:AW_SFX_STOP_EXIT+2], 090h
    mov byte [es:AW_MUSIC_STOP_CALL], 0cdh
    mov byte [es:AW_MUSIC_STOP_CALL+1], 062h
    mov byte [es:AW_MUSIC_STOP_CALL+2], 090h
    mov byte [es:AW_MUSIC_STOP_CALL+3], 090h
    mov byte [cs:patch_installed], 1
%ifdef INTEGRATION_TEST
    ; Test-only build: terminate the child at the verified materialization
    ; point so the parent exercises cleanup and vector restoration.
    mov ax, 4c00h
    pushf
    call far [cs:old_int21]
%endif
    ret
.reject:
    mov byte [cs:runtime_error], 1
    ret

verify_runtime:
    mov si, AW_SB_DETECT
    mov cx, 32
    call rolling_checksum
    cmp ax, SUM_SB_DETECT
    jne .fail
    mov si, AW_SB_START
    mov cx, 32
    call rolling_checksum
    cmp ax, SUM_SB_START
    jne .fail
    mov si, AW_DISPATCH_TEST
    mov cx, 48
    call rolling_checksum
    cmp ax, SUM_DISPATCH
    jne .fail
    mov si, AW_SB_SINK_TEST
    mov cx, 6
    call rolling_checksum
    cmp ax, SUM_SB_SINK
    jne .fail
    mov si, AW_MIX_ENTRY
    mov cx, 15
    call rolling_checksum
    cmp ax, SUM_MIX_ENTRY
    jne .fail
    mov si, AW_SFX_GUARD
    mov cx, 10
    call rolling_checksum
    cmp ax, SUM_SFX_GUARD
    jne .fail
    mov si, AW_MUSIC_GUARD
    mov cx, 8
    call rolling_checksum
    cmp ax, SUM_MUSIC_GUARD
    jne .fail
    mov si, AW_SFX_STOP_TEST
    mov cx, 19
    call rolling_checksum
    cmp ax, SUM_SFX_STOP
    jne .fail
    mov si, AW_MUSIC_STOP_TEST
    mov cx, 13
    call rolling_checksum
    cmp ax, SUM_MUSIC_STOP
    jne .fail
    clc
    ret
.fail:
    stc
    ret

; AX = ROL16(AX,1)+byte over ES:SI, CX bytes.
rolling_checksum:
    xor ax, ax
.loop:
    rol ax, 1
    xor bx, bx
    mov bl, [es:si]
    add ax, bx
    inc si
    loop .loop
    ret

; ---------------------------------------------------------------------------
; Independently written four-channel shadow engine and GF1 synchronizer

; INT 60h replaces only the original two-byte accumulator clear.  The handler
; takes a very short path on most sample ticks.  Every SYNC_BATCH_TICKS it
; synchronizes GF1 voices and advances the four channel counters as a batch,
; without reading or mixing sample bytes.  This keeps the 10 KHz timer useful
; to the game without burdening a 386 with a full four-channel handler on
; every interrupt.
mixer_hook:
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:mixer_ticks]
    inc dword [cs:mixer_ticks32]
%endif
    inc byte [cs:pending_ticks]
    cmp byte [cs:pending_ticks], SYNC_BATCH_TICKS
    jb .return_to_tail
%ifdef AUDIO_INTEGRATION_TEST
    je .pending_exact
    inc word [cs:pending_anomalies]
.pending_exact:
%endif
    mov byte [cs:pending_ticks], 0
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:sync_batches]
    inc dword [cs:sync_batches32]
%endif
    push eax
    push ebx
    push ecx
    push edx
    push si
    push di
    push bp
    push ds
    push es
    cld

    mov ax, [cs:game_cs]
    mov es, ax
    mov ax, [cs:game_ds]
    mov ds, ax
    mov al, [AW_ACTIVE_MASK]
    mov [cs:cur_active], al
    xor di, di
.channel:
    mov bx, di
    shl bx, 1
    call load_channel_state

    mov ax, di
    mov cl, al
    mov al, 1
    shl al, cl
    mov [cs:cur_bit], al
    test [cs:cur_active], al
    jnz .active

    test [cs:hw_active], al
    jz .save
    mov ax, di
    call gf1_stop_voice
    mov al, [cs:cur_bit]
    not al
    and [cs:hw_active], al
    mov byte [cs:channel_slot+di], 0ffh
    jmp .save

.active:
    mov al, [cs:cur_bit]
    test [cs:hw_active], al
    jz .start
    mov ax, [cs:cur_seg]
    cmp ax, [cs:last_seg+bx]
    jne .start
    cmp word [cs:cur_off], 8
    jne .updates
    cmp word [cs:last_off+bx], 8
    jne .start
    mov ax, [cs:cur_rem]
    cmp ax, [cs:last_rem+bx]
    ja .start
    jmp .updates
.start:
    call start_channel
    cmp byte [cs:start_result], 1
    jne .save
    jmp .advance

.updates:
    mov al, [cs:cur_step_frac]
    cmp al, [cs:last_step_frac+di]
    jne .pitch
    mov al, [cs:cur_step_int]
    cmp al, [cs:last_step_int+di]
    je .volume
.pitch:
    call update_channel_frequency
.volume:
    mov bx, di
    shl bx, 1
    mov ax, [cs:cur_vol]
    cmp ax, [cs:last_vol+bx]
    je .loop_sync
    call update_channel_volume
.loop_sync:
    mov bx, di
    shl bx, 1
    mov ax, [cs:cur_off]
    cmp ax, [cs:last_off+bx]
    jae .advance
    cmp ax, [cs:cur_loop_off]
    jne .advance
    call resync_channel_position

.advance:
    mov bx, di
    shl bx, 1
    call shadow_advance_batch
.save:
    mov bx, di
    shl bx, 1
    call save_channel_state
    inc di
    cmp di, CHANNEL_COUNT
    jb .channel

%ifdef AUDIO_INTEGRATION_TEST
    cmp byte [cs:runtime_error], 0
    jne .test_terminate
%ifdef DIAGNOSTIC_EARLY_EXIT
    cmp word [cs:mixer_ticks], 4096
    jae .test_terminate
%endif
    cmp word [cs:mixer_ticks], 256
    jb .test_continue
    cmp word [cs:sync_batches], 1
    jb .test_continue
    cmp word [cs:voice_starts], 1
    jb .test_continue
    cmp word [cs:stop_sync_calls], 1
    jb .test_continue
%ifdef TARGET_OOTW
    cmp byte [cs:preload_ready], 1
    jne .test_continue
    cmp byte [cs:preload_count], 97
    jne .test_continue
%endif
.test_terminate:
    mov ax, 4c00h
    pushf
    call far [cs:old_int21]
.test_continue:
%endif

    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop edx
    pop ecx
    pop ebx
    pop eax
.return_to_tail:
    xor dx, dx
    push bp
    mov bp, sp
    mov word [ss:bp+2], AW_MIX_TAIL
    pop bp
    iret

load_channel_state:
    mov si, [cs:op_seg+bx]
    mov ax, [es:si]
    mov [cs:cur_seg], ax
    mov si, [cs:op_off+bx]
    mov ax, [es:si]
    mov [cs:cur_off], ax
    mov si, [cs:op_vol+bx]
    mov ax, [es:si]
    mov [cs:cur_vol], ax
    mov si, [cs:op_frac+bx]
    mov al, [es:si]
    mov [cs:cur_frac], al
    mov si, [cs:op_step_frac+bx]
    mov al, [es:si]
    mov [cs:cur_step_frac], al
    mov si, [cs:op_step_int+bx]
    mov al, [es:si]
    mov [cs:cur_step_int], al
    mov si, [cs:op_rem+bx]
    mov ax, [es:si]
    mov [cs:cur_rem], ax
    mov si, [cs:loop_off+bx]
    mov ax, [si]
    mov [cs:cur_loop_off], ax
    mov si, [cs:loop_seg+bx]
    mov ax, [si]
    mov [cs:cur_loop_seg], ax
    mov si, [cs:loop_rem+bx]
    mov ax, [si]
    mov [cs:cur_loop_rem], ax
    ret

save_channel_state:
    mov ax, [cs:cur_seg]
    mov [cs:last_seg+bx], ax
    mov ax, [cs:cur_off]
    mov [cs:last_off+bx], ax
    mov ax, [cs:cur_vol]
    mov [cs:last_vol+bx], ax
    mov ax, [cs:cur_rem]
    mov [cs:last_rem+bx], ax
    mov al, [cs:cur_step_frac]
    mov [cs:last_step_frac+di], al
    mov al, [cs:cur_step_int]
    mov [cs:last_step_int+di], al
    mov ax, [cs:cur_loop_off]
    mov [cs:last_loop_off+bx], ax
    mov ax, [cs:cur_loop_seg]
    mov [cs:last_loop_seg+bx], ax
    mov ax, [cs:cur_loop_rem]
    mov [cs:last_loop_rem+bx], ax
    ret

; Advance a complete synchronization batch with one fixed-point update when
; the sample cannot end in this batch.  The boundary fallback below retains
; the original tick-by-tick behavior, including its discarded overrun on a
; loop or one-shot transition.
shadow_advance_batch:
    mov si, [cs:op_frac+bx]
    xor ax, ax
    mov al, [es:si]
    xor dx, dx
    mov dl, [cs:cur_step_frac]
    shl dx, 4
    add ax, dx
    mov [cs:batch_fraction], al
    mov cl, ah
    xor ch, ch
    xor dx, dx
    mov dl, [cs:cur_step_int]
    shl dx, 4
    add dx, cx
    mov bp, dx

    mov si, [cs:op_rem+bx]
    mov ax, [es:si]
    cmp ax, bp
    jb .boundary
    sub ax, bp
    mov [es:si], ax
    mov [cs:cur_rem], ax
    mov si, [cs:op_off+bx]
    mov ax, [es:si]
    add ax, bp
    mov [es:si], ax
    mov [cs:cur_off], ax
    mov si, [cs:op_frac+bx]
    mov al, [cs:batch_fraction]
    mov [es:si], al
    mov [cs:cur_frac], al
    ret

.boundary:
    mov bp, SYNC_BATCH_TICKS
.tick:
    call shadow_advance_tick
    mov al, [cs:cur_bit]
    test [AW_ACTIVE_MASK], al
    jz .reload
    dec bp
    jnz .tick
.reload:
    call load_channel_state
    ret

; Reproduce one observed 8.8 source-position and loop-state transition.
; No sample lookup, scaling, summing, or PCM output occurs here.
shadow_advance_tick:
    mov si, [cs:op_frac+bx]
    mov al, [es:si]
    add al, [cs:cur_step_frac]
    mov [es:si], al
    mov dl, [cs:cur_step_int]
    adc dl, 0
    xor dh, dh

    mov si, [cs:op_off+bx]
    mov ax, [es:si]
    add ax, dx
    mov [es:si], ax
    mov si, [cs:op_rem+bx]
    mov ax, [es:si]
    sub ax, dx
    jnc .store_remaining

    mov ax, [cs:cur_loop_seg]
    mov si, [cs:op_seg+bx]
    mov [es:si], ax
    mov ax, [cs:cur_loop_off]
    mov si, [cs:op_off+bx]
    mov [es:si], ax
    mov si, [cs:op_frac+bx]
    mov byte [es:si], 0
    mov ax, [cs:cur_loop_rem]
    mov si, [cs:op_rem+bx]
    mov [es:si], ax
    or ax, ax
    jnz .done
    mov al, [cs:cur_bit]
    not al
    and [AW_ACTIVE_MASK], al
    sub word [AW_MIX_WORK_SIZE], 0400h
    ret
.store_remaining:
    mov [es:si], ax
.done:
    ret

start_channel:
    push bx
    push cx
    push dx
    push si
    push bp
    mov byte [cs:start_result], 0

    ; A restarted channel may be using the cache slot selected for eviction.
    ; Silence it before any PIO upload can overwrite memory under the voice.
    mov al, [cs:cur_bit]
    test [cs:hw_active], al
    jz .old_voice_stopped
    mov ax, di
    call gf1_stop_voice
.old_voice_stopped:

    mov byte [cs:current_failure], 1
    mov ax, [cs:cur_seg]
    or ax, ax
    jnz .source_present
    mov al, [cs:cur_bit]
    not al
    and [cs:hw_active], al
    mov byte [cs:channel_slot+di], 0ffh
    mov byte [cs:current_failure], 0
    jmp .done
.source_present:
    mov byte [cs:current_failure], 2
    push ds
    mov ds, ax
    mov ax, [0]
    xchg al, ah
    shl ax, 1
    jc .source_fail
    mov [cs:sample_intro], ax
    mov ax, [2]
    xchg al, ah
    shl ax, 1
    jc .source_fail
    mov [cs:sample_loop], ax
    add ax, [cs:sample_intro]
    jc .source_fail
    cmp ax, 2
    jb .source_fail
    cmp ax, 0fff8h
    ja .source_fail
    mov [cs:sample_total], ax

    mov ax, [8]
    mov [cs:sample_sig_a], ax
    mov bx, [cs:sample_total]
    shr bx, 1
    add bx, 8
    mov ax, [bx]
    mov [cs:sample_sig_b], ax
    mov bx, [cs:sample_total]
    add bx, 6
    mov ax, [bx]
    mov [cs:sample_sig_c], ax
    pop ds
    mov byte [cs:current_failure], 0

    call find_preloaded_sample
    jc .cache_lookup
    xor bx, bx
    mov bl, [cs:selected_preload]
    mov si, bx
    shl si, 1
    mov bx, di
    shl bx, 1
    mov ax, [cs:preload_base_low+si]
    mov [cs:channel_base_low+bx], ax
    mov ax, [cs:preload_base_high+si]
    mov [cs:channel_base_high+bx], ax
    mov byte [cs:channel_slot+di], 0ffh
    jmp .sample_ready

.cache_lookup:
    call find_cache_slot
    jnc .slot_ready
    call choose_cache_slot
    jnc .slot_chosen
    mov byte [cs:current_failure], 3
    jmp .fail
.slot_chosen:
    mov [cs:selected_slot], al
    xor ah, ah
    add al, [cs:cache_base_slot]
    mov [cs:dram_addr_high], ax
    mov word [cs:dram_addr_low], 0
    push ds
    mov ds, [cs:cur_seg]
    mov si, 8
    mov cx, [cs:sample_total]
    call gus_upload
    pop ds
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:cache_uploads]
%endif
    call store_cache_metadata
.slot_ready:
    mov al, [cs:selected_slot]
    mov [cs:channel_slot+di], al
    inc word [cs:cache_clock]
    xor ah, ah
    mov si, ax
    shl si, 1
    mov ax, [cs:cache_clock]
    mov [cs:cache_stamp+si], ax

    mov bx, di
    shl bx, 1
    mov word [cs:channel_base_low+bx], 0
    xor ax, ax
    mov al, [cs:selected_slot]
    add al, [cs:cache_base_slot]
    mov [cs:channel_base_high+bx], ax

.sample_ready:
    mov al, [cs:cur_bit]
    or [cs:hw_active], al
    mov byte [cs:current_failure], 4
    mov ax, [cs:cur_off]
    cmp ax, 8
    jb .fail_started
    sub ax, 8
    cmp ax, [cs:sample_total]
    jae .fail_started
    mov dx, ax
    mov bx, di
    shl bx, 1
    mov ax, [cs:channel_base_low+bx]
    add ax, dx
    mov [cs:voice_begin_low], ax
    mov ax, [cs:channel_base_high+bx]
    adc ax, 0
    mov [cs:voice_begin_high], ax
    mov byte [cs:current_failure], 0

    mov ax, [cs:channel_base_low+bx]
    add ax, [cs:sample_intro]
    mov [cs:voice_loop_low], ax
    mov ax, [cs:channel_base_high+bx]
    adc ax, 0
    mov [cs:voice_loop_high], ax

    mov ax, [cs:sample_intro]
    mov dx, [cs:sample_loop]
    or dx, dx
    jz .one_shot
    add ax, dx
    dec ax
    mov byte [cs:voice_mode], 08h
    jmp .end_address
.one_shot:
    mov ax, [cs:sample_intro]
    dec ax
    mov byte [cs:voice_mode], 0
.end_address:
    add ax, [cs:channel_base_low+bx]
    mov [cs:voice_end_low], ax
    mov ax, [cs:channel_base_high+bx]
    adc ax, 0
    mov [cs:voice_end_high], ax
.voice_ready:
    call compute_frequency
    mov [cs:voice_frequency], ax
    call compute_volume
    mov [cs:voice_volume], ax
    mov ax, di
    mov [cs:voice_number], al
    mov al, [cs:pan_positions+di]
    mov [cs:voice_pan], al
    call gf1_start_voice
    mov byte [cs:start_result], 1
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:voice_starts]
%endif
    jmp .done

.source_fail:
    pop ds
%ifdef AUDIO_INTEGRATION_TEST
    mov al, [cs:current_failure]
    mov [cs:last_failure], al
    inc word [cs:transient_source_failures]
%endif
.fail:
    mov al, [cs:cur_bit]
    not al
    and [cs:hw_active], al
    mov byte [cs:channel_slot+di], 0ffh
    jmp .done
.fail_started:
    mov ax, di
    call gf1_stop_voice
%ifdef AUDIO_INTEGRATION_TEST
    mov al, [cs:current_failure]
    mov [cs:last_failure], al
    inc word [cs:transient_source_failures]
%endif
    jmp .fail
.done:
    pop bp
    pop si
    pop dx
    pop cx
    pop bx
    ret

find_preloaded_sample:
    cmp byte [cs:preload_ready], 1
    jne .miss

%ifdef TARGET_OOTW
    ; The common case is a voice restarting the same resource.  Revalidate
    ; the cached resource ID against the live table so a recycled DOS segment
    ; can never select stale GF1 data, then map the ID to its preload slot in
    ; constant time.
    mov dl, [cs:channel_resource_id+di]
    cmp dl, 0ffh
    je .resource_scan
    xor dh, dh
    mov si, dx
    cmp si, [cs:memlist_entries]
    jae .resource_scan
    mov bx, si
    shl bx, 2
    mov ax, si
    shl ax, 4
    add bx, ax
    add bx, AW_RESOURCE_TABLE
    cmp byte [bx], 1
    jne .resource_scan
    mov ax, [bx+2]
    cmp ax, [cs:cur_seg]
    jne .resource_scan
    xor ax, ax
    mov al, [cs:channel_preload_index+di]
    cmp al, [cs:preload_count]
    jae .resource_scan
    mov si, ax
    cmp byte [cs:preload_resource_id+si], dl
    jne .resource_scan
    mov bx, si
    shl bx, 1
    mov ax, [cs:preload_intro+bx]
    cmp ax, [cs:sample_intro]
    jne .resource_scan
    mov ax, [cs:preload_loop+bx]
    cmp ax, [cs:sample_loop]
    je .found

    ; Resolve the live segment through the game's 20-byte resource table.
    ; Resource identity remains stable if the game transforms payload bytes.
.resource_scan:
    xor si, si
    mov cx, [cs:memlist_entries]
.resource_loop:
    or cx, cx
    jz .resource_miss
    mov bx, si
    shl bx, 2
    mov ax, si
    shl ax, 4
    add bx, ax
    add bx, AW_RESOURCE_TABLE
    cmp byte [bx], 1
    jne .next_resource
    mov ax, [bx+2]
    cmp ax, [cs:cur_seg]
    je .resource_found
.next_resource:
    inc si
    dec cx
    jmp .resource_loop

.resource_found:
    cmp si, 256
    jae .resource_miss
    mov dx, si
    xor ax, ax
    mov bx, si
    mov al, [cs:resource_preload_index+bx]
    cmp al, 0ffh
    je .resource_miss
    cmp al, [cs:preload_count]
    jae .resource_miss
    mov si, ax
    cmp byte [cs:preload_resource_id+si], dl
    jne .resource_miss
    mov bx, si
    shl bx, 1
    mov ax, [cs:preload_intro+bx]
    cmp ax, [cs:sample_intro]
    jne .resource_miss
    mov ax, [cs:preload_loop+bx]
    cmp ax, [cs:sample_loop]
    jne .resource_miss
    mov [cs:channel_resource_id+di], dl
    mov ax, si
    mov [cs:channel_preload_index+di], al
    mov bx, di
    shl bx, 1
    mov ax, [cs:cur_seg]
    mov [cs:channel_preload_seg+bx], ax
    jmp .found
.resource_miss:
    mov byte [cs:channel_resource_id+di], 0ffh
%endif

    ; Signature lookup is both the conservative Another World path and the
    ; fallback when a live Out of This World resource cannot be identified.
    ; A per-channel cache makes repeated starts constant-time while retaining
    ; full metadata validation.
.signature_cached:
    mov bx, di
    shl bx, 1
    mov ax, [cs:channel_preload_seg+bx]
    cmp ax, [cs:cur_seg]
    jne .signature_start
    xor ax, ax
    mov al, [cs:channel_preload_index+di]
    cmp al, [cs:preload_count]
    jae .signature_start
    mov si, ax
    mov bx, si
    shl bx, 1
    mov ax, [cs:preload_intro+bx]
    cmp ax, [cs:sample_intro]
    jne .signature_start
    mov ax, [cs:preload_loop+bx]
    cmp ax, [cs:sample_loop]
    jne .signature_start
    mov ax, [cs:preload_sig_a+bx]
    cmp ax, [cs:sample_sig_a]
    jne .signature_start
    mov ax, [cs:preload_sig_b+bx]
    cmp ax, [cs:sample_sig_b]
    jne .signature_start
    mov ax, [cs:preload_sig_c+bx]
    cmp ax, [cs:sample_sig_c]
    je .found

.signature_start:
    xor si, si
.signature_loop:
    xor ax, ax
    mov al, [cs:preload_count]
    cmp si, ax
    jae .miss
    mov bx, si
    shl bx, 1
    mov ax, [cs:preload_intro+bx]
    cmp ax, [cs:sample_intro]
    jne .next_signature
    mov ax, [cs:preload_loop+bx]
    cmp ax, [cs:sample_loop]
    jne .next_signature
    mov ax, [cs:preload_sig_a+bx]
    cmp ax, [cs:sample_sig_a]
    jne .next_signature
    mov ax, [cs:preload_sig_b+bx]
    cmp ax, [cs:sample_sig_b]
    jne .next_signature
    mov ax, [cs:preload_sig_c+bx]
    cmp ax, [cs:sample_sig_c]
    jne .next_signature
    mov byte [cs:channel_resource_id+di], 0ffh
    mov ax, si
    mov [cs:channel_preload_index+di], al
    mov bx, di
    shl bx, 1
    mov ax, [cs:cur_seg]
    mov [cs:channel_preload_seg+bx], ax
.found:
    mov ax, si
    mov [cs:selected_preload], al
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:preload_hits]
%endif
    clc
    ret
.next_signature:
    inc si
    jmp .signature_loop
.miss:
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:preload_misses]
%endif
    stc
    ret

find_cache_slot:
    xor si, si
.loop:
    xor ax, ax
    mov al, [cs:cache_slot_count]
    cmp si, ax
    jae .miss
    cmp byte [cs:cache_valid+si], 1
    jne .next
    mov bx, si
    shl bx, 1
    mov ax, [cs:cache_seg+bx]
    cmp ax, [cs:cur_seg]
    jne .next
    mov ax, [cs:cache_intro+bx]
    cmp ax, [cs:sample_intro]
    jne .next
    mov ax, [cs:cache_loop+bx]
    cmp ax, [cs:sample_loop]
    jne .next
    mov ax, [cs:cache_sig_a+bx]
    cmp ax, [cs:sample_sig_a]
    jne .next
    mov ax, [cs:cache_sig_b+bx]
    cmp ax, [cs:sample_sig_b]
    jne .next
    mov ax, [cs:cache_sig_c+bx]
    cmp ax, [cs:sample_sig_c]
    jne .next
    mov ax, si
    mov [cs:selected_slot], al
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:cache_hits]
%endif
    clc
    ret
.next:
    inc si
    jmp .loop
.miss:
    stc
    ret

choose_cache_slot:
    xor si, si
.invalid:
    xor ax, ax
    mov al, [cs:cache_slot_count]
    cmp si, ax
    jae .lru
    cmp byte [cs:cache_valid+si], 0
    je .choose
    inc si
    jmp .invalid
.lru:
    mov byte [cs:best_slot], 0ffh
    mov word [cs:best_stamp], 0ffffh
    xor si, si
.candidate:
    xor ax, ax
    mov al, [cs:cache_slot_count]
    cmp si, ax
    jae .finish
    mov ax, si
    call slot_in_use_by_other
    jc .next
    mov bx, si
    shl bx, 1
    mov ax, [cs:cache_stamp+bx]
    cmp ax, [cs:best_stamp]
    jae .next
    mov [cs:best_stamp], ax
    mov ax, si
    mov [cs:best_slot], al
.next:
    inc si
    jmp .candidate
.finish:
    cmp byte [cs:best_slot], 0ffh
    je .fail
    mov al, [cs:best_slot]
    clc
    ret
.choose:
    mov ax, si
    clc
    ret
.fail:
    stc
    ret

; AX = slot, DI = current channel.  Carry means another active channel owns it.
slot_in_use_by_other:
    push ax
    push bx
    push cx
    push dx
    push si
    mov dl, al
    xor si, si
.loop:
    cmp si, di
    je .next
    mov ax, si
    mov cl, al
    mov al, 1
    shl al, cl
    test [cs:hw_active], al
    jz .next
    mov al, [cs:channel_slot+si]
    cmp al, dl
    je .used
.next:
    inc si
    cmp si, CHANNEL_COUNT
    jb .loop
    clc
    jmp .done
.used:
    stc
.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

store_cache_metadata:
    xor ah, ah
    mov al, [cs:selected_slot]
    mov si, ax
    mov byte [cs:cache_valid+si], 1
    shl si, 1
    mov ax, [cs:cur_seg]
    mov [cs:cache_seg+si], ax
    mov ax, [cs:sample_intro]
    mov [cs:cache_intro+si], ax
    mov ax, [cs:sample_loop]
    mov [cs:cache_loop+si], ax
    mov ax, [cs:sample_sig_a]
    mov [cs:cache_sig_a+si], ax
    mov ax, [cs:sample_sig_b]
    mov [cs:cache_sig_b+si], ax
    mov ax, [cs:sample_sig_c]
    mov [cs:cache_sig_c+si], ax
    ret

update_channel_frequency:
    call compute_frequency
    mov bx, ax
    mov ax, di
    call gf1_voice_frequency
    ret

update_channel_volume:
    call compute_volume
    mov bx, ax
    mov ax, di
    call gf1_voice_volume
    ret

resync_channel_position:
    mov si, di
    shl si, 1
    mov cx, [cs:cur_off]
    cmp cx, 8
    jb .done
    sub cx, 8
    add cx, [cs:channel_base_low+si]
    mov bx, [cs:channel_base_high+si]
    adc bx, 0
    mov ax, di
    call gf1_voice_current_address
.done:
    ret

; AX = round((8.8 step * game output rate) * 1024 / 44100).
compute_frequency:
    xor eax, eax
    mov ax, [cs:cur_step_frac]
    movzx ebx, word [AW_SAMPLE_RATE]
    mul ebx
    shl eax, 2
    add eax, 22050
    xor edx, edx
    mov ecx, 44100
    div ecx
    and ax, 0fffeh
    jnz .done
    cmp word [cs:cur_step_frac], 0
    je .done
    mov ax, 2
.done:
    ret

; Match the original four-way mix headroom: levels 0..63 map to 8..16/64.
compute_volume:
    mov ax, [cs:cur_vol]
    sub ax, 06e66h
    jc .minimum
    mov al, ah
    cmp al, 63
    jbe .level_ok
    mov al, 63
.level_ok:
    inc al
    shr al, 3
    add al, 8
    jmp .lookup
.minimum:
    mov al, 8
.lookup:
    xor ah, ah
    shl ax, 1
    mov bx, ax
    mov ax, [cs:volume_table+bx]
    ret

; INT 61h replaces the three-byte jump at the single-channel stop path.  The
; game has already cleared its active bit and its two self-modified operands;
; mirror that change on the GF1, then resume at the routine's common epilogue.
stop_sync_hook:
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:stop_sync_calls]
%endif
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push ds

    mov ax, [cs:game_ds]
    mov ds, ax
    mov dl, [AW_ACTIVE_MASK]
    xor si, si
.channel:
    mov cx, si
    mov al, 1
    shl al, cl
    test [cs:hw_active], al
    jz .next
    test dl, al
    jnz .next
    mov ax, si
    call gf1_stop_voice
    mov cx, si
    mov al, 1
    shl al, cl
    not al
    and [cs:hw_active], al
    mov byte [cs:channel_slot+si], 0ffh
.next:
    inc si
    cmp si, CHANNEL_COUNT
    jb .channel

    pop ds
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov word [ss:bp+2], AW_SFX_COMMON_EXIT
    pop bp
    iret

; INT 62h replaces the backend reset call used by the global music-stop path.
; Reproduce the state changes made by the original SB mixer reset without
; touching the SB, then silence all GF1 voices.
stop_all_hook:
%ifdef AUDIO_INTEGRATION_TEST
    inc word [cs:stop_all_calls]
%endif
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    call gus_quiet
    mov ax, [cs:game_ds]
    mov ds, ax
    mov ax, [cs:game_cs]
    mov es, ax
    xor si, si
.clear_channel:
    mov bx, si
    shl bx, 1
    mov di, [cs:op_seg+bx]
    mov word [es:di], 0
    mov di, [cs:op_off+bx]
    mov word [es:di], 0
    inc si
    cmp si, CHANNEL_COUNT
    jb .clear_channel
    mov byte [AW_ACTIVE_MASK], 0
    mov byte [AW_AUX_ACTIVE], 0
    mov byte [AW_DEVICE_ACTIVE], 0
    mov word [AW_MIX_WORK_SIZE], AW_MIX_WORK_RESET
    mov byte [cs:hw_active], 0
    mov byte [cs:pending_ticks], 0
    mov dword [cs:channel_slot], 0ffffffffh

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

print_dos:
    mov ah, 09h
    int 21h
    ret

print_hex_word:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov cx, 4
.digit:
    rol bx, 4
    mov dl, bl
    and dl, 0fh
    add dl, '0'
    cmp dl, '9'
    jbe .emit
    add dl, 'A'-'9'-1
.emit:
    mov ah, 02h
    int 21h
    loop .digit
    pop dx
    pop cx
    pop bx
    pop ax
    ret

%ifdef AUDIO_INTEGRATION_TEST
print_audio_test_status:
    mov dx, msg_test_ticks
    call print_dos
    mov ax, [mixer_ticks]
    call print_hex_word
    mov dx, msg_test_ticks32_hi
    call print_dos
    mov ax, [mixer_ticks32+2]
    call print_hex_word
    mov dx, msg_test_ticks32_lo
    call print_dos
    mov ax, [mixer_ticks32]
    call print_hex_word
    mov dx, msg_test_batches
    call print_dos
    mov ax, [sync_batches]
    call print_hex_word
    mov dx, msg_test_batches32_hi
    call print_dos
    mov ax, [sync_batches32+2]
    call print_hex_word
    mov dx, msg_test_batches32_lo
    call print_dos
    mov ax, [sync_batches32]
    call print_hex_word
    mov dx, msg_test_anomalies
    call print_dos
    mov ax, [pending_anomalies]
    call print_hex_word
    mov dx, msg_test_starts
    call print_dos
    mov ax, [voice_starts]
    call print_hex_word
    mov dx, msg_test_stops
    call print_dos
    mov ax, [stop_sync_calls]
    call print_hex_word
    mov dx, msg_test_stop_all
    call print_dos
    mov ax, [stop_all_calls]
    call print_hex_word
    mov dx, msg_test_hits
    call print_dos
    mov ax, [preload_hits]
    call print_hex_word
    mov dx, msg_test_misses
    call print_dos
    mov ax, [preload_misses]
    call print_hex_word
    mov dx, msg_test_cache_hits
    call print_dos
    mov ax, [cache_hits]
    call print_hex_word
    mov dx, msg_test_uploads
    call print_dos
    mov ax, [cache_uploads]
    call print_hex_word
    mov dx, msg_test_fail_count
    call print_dos
    mov ax, [runtime_fail_count]
    call print_hex_word
    mov dx, msg_test_fail_reason
    call print_dos
    xor ax, ax
    mov al, [last_failure]
    call print_hex_word
    mov dx, msg_test_transient
    call print_dos
    mov ax, [transient_source_failures]
    call print_hex_word
    mov dx, msg_test_preload
    call print_dos
    xor ax, ax
    mov al, [preload_count]
    call print_hex_word
    mov dx, msg_test_ready
    call print_dos
    xor ax, ax
    mov al, [preload_ready]
    call print_hex_word
    mov dx, msg_test_runtime
    call print_dos
    xor ax, ax
    mov al, [runtime_error]
    call print_hex_word
    mov dx, msg_crlf
    call print_dos
    ret
%endif

%include "gf1.inc"

; ---------------------------------------------------------------------------
; Runtime map derived independently from the supported executable's
; materialized instructions.  These are operand locations, not copied code.

%ifdef TARGET_OOTW
op_seg          dw 0356fh,035dch,03649h,036b6h
op_off          dw 03574h,035e1h,0364eh,036bbh
op_vol          dw 0357dh,035eah,03657h,036c4h
op_frac         dw 0358ah,035f7h,03664h,036d1h
op_step_frac    dw 0358eh,035fbh,03668h,036d5h
op_step_int     dw 03591h,035feh,0366bh,036d8h
op_rem          dw 035a3h,03610h,0367dh,036eah

loop_off        dw 0afb0h,0afb6h,0afbch,0afc2h
loop_seg        dw 0afb2h,0afb8h,0afbeh,0afc4h
loop_rem        dw 0afb4h,0afbah,0afc0h,0afc6h
%else
op_seg          dw 0334fh,033bch,03429h,03496h
op_off          dw 03354h,033c1h,0342eh,0349bh
op_vol          dw 0335dh,033cah,03437h,034a4h
op_frac         dw 0336ah,033d7h,03444h,034b1h
op_step_frac    dw 0336eh,033dbh,03448h,034b5h
op_step_int     dw 03371h,033deh,0344bh,034b8h
op_rem          dw 03383h,033f0h,0345dh,034cah

loop_off        dw 0aee8h,0aeeeh,0aef4h,0aefah
loop_seg        dw 0aeeah,0aef0h,0aef6h,0aefch
loop_rem        dw 0aeech,0aef2h,0aef8h,0aefeh
%endif

; Independently derived linear 0..64 -> GF1 exponent/mantissa values.  AWGUS
; currently uses entries 8..16 to retain the original mixer's headroom.
volume_table:
    dw 00000h,09ff0h,0aff0h,0b800h,0bff0h,0c400h,0c800h,0cc00h
    dw 0cff0h,0d200h,0d400h,0d600h,0d800h,0da00h,0dc00h,0de00h
    dw 0dff0h,0e100h,0e200h,0e300h,0e400h,0e500h,0e600h,0e700h
    dw 0e800h,0e900h,0ea00h,0eb00h,0ec00h,0ed00h,0ee00h,0ef00h
    dw 0eff0h,0f080h,0f100h,0f180h,0f200h,0f280h,0f300h,0f380h
    dw 0f400h,0f480h,0f500h,0f580h,0f600h,0f680h,0f700h,0f780h
    dw 0f800h,0f880h,0f900h,0f980h,0fa00h,0fa80h,0fb00h,0fb80h
    dw 0fc00h,0fc80h,0fd00h,0fd80h,0fe00h,0fe80h,0ff00h,0ff80h
    dw 0fff0h

irq_lut          db 0,0,1,3,0,2,0,4,0,0,0,5,6,0,0,7
dma_lut          db 0,1,0,2,0,3,4,5
ultrasnd_key     db 'ULTRASND='

game_filename    db GAME_BASENAME,0
config_name      db 'CONFIG.DAT',0
msg_banner       db APP_TAG,' 0.3.1-alpha - experimental GF1 launcher',13,10,'$'
msg_bad_options  db APP_TAG,': invalid option. Use /? for syntax.',13,10,'$'
msg_usage        db 'Usage: ',APP_TAG,' [/P:C | /P:0,15,0,15]',13,10
                 db '  default: voices 0/2 left, voices 1/3 right',13,10
                 db '  /P:C:    center all four voices',13,10
                 db '  /P:n,n,n,n: per-voice GF1 pan values 0..15',13,10,'$'
msg_bad_config   db APP_TAG,': invalid or missing ULTRASND setting.',13,10,'$'
msg_bad_game     db APP_TAG,': unsupported ',GAME_BASENAME,'.',13,10,'$'
msg_no_memory    db APP_TAG,': not enough conventional memory.',13,10,'$'
msg_no_gus       db APP_TAG,': GF1 or sample RAM not detected.',13,10,'$'
msg_preload_wait db APP_TAG,': loading music and sound effects into GUS RAM, please wait...$'
msg_preload_clear db 13
                  times 79 db ' '
                  db 13,'$'
msg_preload_ok   db APP_TAG,': sound bank preloaded to GF1 RAM.',13,10,'$'
msg_preload_fallback db APP_TAG,': full preload unavailable; using on-demand cache.',13,10,'$'
msg_exec_failed  db APP_TAG,': DOS EXEC failed, error $'
msg_patch_missing db APP_TAG,': runtime hook was not installed.',13,10,'$'
msg_runtime_error db APP_TAG,': GF1 runtime error detected.',13,10,'$'
msg_patch_ok     db APP_TAG,': game exited; GF1 hook was active.',13,10,'$'
msg_crlf         db 13,10,'$'
%ifdef AUDIO_INTEGRATION_TEST
msg_test_ticks   db 'ticks=$'
msg_test_ticks32_hi db ' ticks32=$'
msg_test_ticks32_lo db ':$'
msg_test_batches db ' batches=$'
msg_test_batches32_hi db ' batches32=$'
msg_test_batches32_lo db ':$'
msg_test_anomalies db ' anomalies=$'
msg_test_starts  db ' starts=$'
msg_test_stops   db ' stops=$'
msg_test_stop_all db ' stopall=$'
msg_test_hits    db ' hits=$'
msg_test_misses  db ' misses=$'
msg_test_cache_hits db ' cachehits=$'
msg_test_uploads db ' uploads=$'
msg_test_fail_count db ' fails=$'
msg_test_fail_reason db ' reason=$'
msg_test_transient db ' transient=$'
msg_test_preload db ' preload=$'
msg_test_ready   db ' ready=$'
msg_test_runtime db ' runtime=$'
%endif

old_int21        dd 0
old_int01        dd 0
old_int60        dd 0
old_int61        dd 0
old_int62        dd 0
psp_segment      dw 0
caller_cs        dw 0
game_cs          dw 0
game_ds          dw 0
file_handle      dw 0ffffh
memlist_handle   dw 0ffffh
bank_handle      dw 0ffffh
work_segment     dw 0
file_crc32       dd 0
exec_error       dw 0
child_exit_code  db 0
exec_failed      db 0
patch_installed  db 0
runtime_error    db 0
mixer_ticks      dw 0
mixer_ticks32    dd 0
sync_batches     dw 0
sync_batches32   dd 0
pending_anomalies dw 0
voice_starts     dw 0
stop_sync_calls  dw 0
stop_all_calls   dw 0
preload_hits     dw 0
preload_misses   dw 0
cache_hits       dw 0
cache_uploads    dw 0
runtime_fail_count dw 0
transient_source_failures dw 0
current_failure db 0
last_failure    db 0
start_result    db 0
pending_ticks    db 0
preload_ready    db 0
preload_count    db 0
current_bank     db 0ffh
cache_base_slot  db 0
memlist_index    dw 0
memlist_entries  dw 0

exec_tail        db 0,13
exec_params      times 14 db 0

cur_active       db 0
cur_bit          db 0
hw_active        db 0
channel_slot     times CHANNEL_COUNT db 0ffh
channel_base_low times CHANNEL_COUNT dw 0
channel_base_high times CHANNEL_COUNT dw 0
channel_resource_id times CHANNEL_COUNT db 0ffh
channel_preload_index times CHANNEL_COUNT db 0ffh
channel_preload_seg times CHANNEL_COUNT dw 0
pan_positions    db 0,15,0,15
cur_seg          dw 0
cur_off          dw 0
cur_vol          dw 0
cur_rem          dw 0
cur_loop_off     dw 0
cur_loop_seg     dw 0
cur_loop_rem     dw 0
cur_frac         db 0
cur_step_frac    db 0
cur_step_int     db 0
batch_fraction   db 0

last_seg         times CHANNEL_COUNT dw 0ffffh
last_off         times CHANNEL_COUNT dw 0ffffh
last_vol         times CHANNEL_COUNT dw 0ffffh
last_rem         times CHANNEL_COUNT dw 0ffffh
last_loop_off    times CHANNEL_COUNT dw 0ffffh
last_loop_seg    times CHANNEL_COUNT dw 0ffffh
last_loop_rem    times CHANNEL_COUNT dw 0ffffh
last_step_frac   times CHANNEL_COUNT db 0ffh
last_step_int    times CHANNEL_COUNT db 0ffh

sample_intro     dw 0
sample_loop      dw 0
sample_total     dw 0
sample_sig_a     dw 0
sample_sig_b     dw 0
sample_sig_c     dw 0
selected_slot    db 0
selected_preload db 0
best_slot        db 0
best_stamp       dw 0
cache_clock      dw 0
cache_slot_count db 4
cache_valid      times CACHE_MAX_SLOTS db 0
cache_seg        times CACHE_MAX_SLOTS dw 0
cache_intro      times CACHE_MAX_SLOTS dw 0
cache_loop       times CACHE_MAX_SLOTS dw 0
cache_sig_a      times CACHE_MAX_SLOTS dw 0
cache_sig_b      times CACHE_MAX_SLOTS dw 0
cache_sig_c      times CACHE_MAX_SLOTS dw 0
cache_stamp      times CACHE_MAX_SLOTS dw 0

preload_intro    times PRELOAD_MAX_SAMPLES dw 0
preload_resource_id times PRELOAD_MAX_SAMPLES db 0
resource_preload_index times 256 db 0ffh
preload_loop     times PRELOAD_MAX_SAMPLES dw 0
preload_sig_a    times PRELOAD_MAX_SAMPLES dw 0
preload_sig_b    times PRELOAD_MAX_SAMPLES dw 0
preload_sig_c    times PRELOAD_MAX_SAMPLES dw 0
preload_base_low times PRELOAD_MAX_SAMPLES dw 0
preload_base_high times PRELOAD_MAX_SAMPLES dw 0
preload_next     dd 0
sample_base      dd 0

resource_packed  dw 0
resource_size    dw 0
unpack_src       dw 0
unpack_dst       dw 0
unpack_left      dw 0
unpack_reload_count dw 0
unpack_bits      dd 0
unpack_crc       dd 0
unpack_error     db 0

memlist_filename db 'MEMLIST.BIN',0
bank_filename    db 'BANK00',0
mem_entry        times MEM_ENTRY_BYTES db 0

gus_base          dw 0
gus_dma1          dw 0
gus_dma2          dw 0
gus_irq           dw 0
gus_midi_irq      dw 0
gus_voice_port    dw 0
gus_command_port  dw 0
gus_data_low_port dw 0
gus_data_high_port dw 0
gus_status_port   dw 0
gus_dram_port     dw 0
dram_addr_low     dw 0
dram_addr_high    dw 0
peek_value        db 0

voice_number       db 0
voice_mode         db 0
voice_pan          db 7
voice_addr_register db 0
voice_begin_low    dw 0
voice_begin_high   dw 0
voice_loop_low     dw 0
voice_loop_high    dw 0
voice_end_low      dw 0
voice_end_high     dw 0
voice_addr_low     dw 0
voice_addr_high    dw 0
voice_frequency    dw 0
voice_volume       dw 0

io_buffer          times IO_BUFFER_BYTES db 0

align 16
stack_bottom:
    times 1024 db 0
stack_top:
resident_end:

RESIDENT_PARAS equ (resident_end - $$ + 100h + 15) >> 4
