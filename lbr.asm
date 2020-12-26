; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc

; R9 - pointer to data segment

           org     8000h
           lbr     0ff00h
           db      'lbr',0
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0

           org     2000h
           br      start

include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

command:   db      0
libname:   dw      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
fname:     dw      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

lfildes:   db      0,0,0,0
           dw      ldta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

ffildes:   db      0,0,0,0
           dw      fdta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

start:     ldi     high command        ; setup data segment
           phi     r9

           ghi     ra                  ; copy argument address to rf
           phi     rf
           glo     ra
           plo     rf
           sep     scall               ; move past any whitespace
           dw      f_ltrim
           ldi     low command         ; address to store command
           plo     r9
           lda     rf                  ; get command byte
           str     r9                  ; and store
           sep     scall               ; move past any whitespace
           dw      f_ltrim             ; to library name
           ldi     low libname         ; point to libname storage
           plo     r9
loop1:     lda     rf                  ; get byte from arguments
           str     r9                  ; store into filename
           inc     r9
           smi     33                  ; check for whitespace
           bdf     loop1               ; loop until full name copied
           dec     r9                  ; move back to last char
           ldi     '.'                 ; add .LBR extension
           str     r9
           inc     r9
           ldi     'l'                 ; add .LBR extension
           str     r9
           inc     r9
           ldi     'b'                 ; add .LBR extension
           str     r9
           inc     r9
           ldi     'r'                 ; add .LBR extension
           str     r9
           inc     r9
           ldi     0                   ; add .LBR extension
           str     r9
           inc     r9
           sep     scall               ; move past any whitespace
           dw      f_ltrim
           ldi     low command         ; point to stored command
           plo     r9
           ldn     r9                  ; retrieve command
           smi     'a'                 ; check for Add command
           lbz     cmd_add             ; jump if add command
           smi     3                   ; check for Delete command

           smi     1                   ; check for Extract command
           lbz     cmd_ext             ; jump if so
           smi     7                   ; check for List command
           lbz     cmd_list            ; jump if so


usage_err: ldi     high usage          ; point to usage message
           phi     rf
           ldi     low usage
           plo     rf
           sep     scall               ; and display it
           dw      o_msg
           lbr     o_wrmboot           ; return to Elf/OS

liberr:    ldi     high libmsg         ; point to usage message
           phi     rf
           ldi     low libmsg
           plo     rf
           sep     scall               ; and display it
           dw      o_msg
           lbr     o_wrmboot           ; return to Elf/OS

open_lib:  ldi     high libname        ; point to library name
           phi     rf
           ldi     low libname
           plo     rf
           ldi     high lfildes        ; point to library fildes
           phi     rd
           ldi     low lfildes
           plo     rd
           lda     r6                  ; get open flags
           plo     r7
           sep     scall               ; open the library file
           dw      o_open
           sep     sret                ; return to caller

; **********************************
; *** Extract files from library ***
; **********************************
cmd_ext:   sep     scall               ; open the library file
           dw      open_lib
           db      0                   ; no special flags
           lbdf    liberr              ; jump if could not open library
ext_loop:  ldi     high fname          ; point to filename buffer
           phi     rf
           ldi     low fname
           plo     rf
ext_nmlp:  ldi     0                   ; need to read 1 byte
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; read it
           dw      o_read
           lbdf    lst_done            ; jump if no more in file
           glo     rc                  ; check bytes read count
           lbz     lst_done            ; jump if end of file
           dec     rf                  ; get last byte read
           ldn     rf                  ; retrieve last read byte
           smi     01ah                ; check for XMODEM pad character
           lbz     lst_done            ; jump if 1E
           lda     rf
           lbnz    ext_nmlp            ; get rest of name
           ldi     high fname          ; point to filename
           phi     rf
           ldi     low fname
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           sep     scall
           dw      crlf
           ldi     high buffer         ; need to read flags and size
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     0                   ; which is 5 bytes
           phi     rc
           ldi     5
           plo     rc
           sep     scall               ; read them
           dw      o_read
           ldi     high fname          ; point to filename
           phi     rf
           ldi     low fname
           plo     rf
           ldi     low ffildes         ; point to file fildes
           plo     rd 
           ldi     3                   ; create/truncate file
           plo     r7
           sep     scall               ; open the output file
           dw      o_open
           ldi     high buffer         ; need to get file size
           phi     rf
           ldi     low buffer
           plo     rf
           inc     rf
           lda     rf                  ; place into R8:r7
           phi     r8
           lda     rf
           plo     r8
           lda     rf
           phi     r7
           lda     rf
           plo     r7
ext_cplp:  ghi     r8                  ; see if more then 255 bytes remain
           str     r2
           glo     r8
           or
           str     r2
           ghi     r7
           or
           lbnz    ext_m256            ; jump if 256 or more bytes remain
           ldi     0                   ; set count
           phi     rc
           glo     r7
           plo     rc
           ldi     high buffer         ; point to transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     low lfildes         ; need library fildes
           plo     rd
           sep     scall               ; read the bytes
           dw      o_read
           ldi     high buffer         ; point to transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     low ffildes         ; point to file fildes
           plo     rd
           sep     scall               ; write the bytes
           dw      o_write
           sep     scall               ; close the file
           dw      o_close
           ldi     low lfildes         ; need library fildes
           plo     rd
           lbr     ext_loop            ; extract more files
ext_m256:  ldi     1                   ; set to read 256 bytes
           phi     rc
           ldi     0 
           plo     rc
           ldi     high buffer         ; point to transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     low lfildes         ; need library fildes
           plo     rd
           sep     scall               ; read the bytes
           dw      o_read
           ldi     high buffer         ; point to transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     low ffildes         ; point to file fildes
           plo     rd
           sep     scall               ; write the bytes
           dw      o_write
           ghi     r7                  ; update byte count
           smi     1
           phi     r7
           glo     r8                  ; propagate borrow
           smbi    0
           plo     r8
           ghi     r8
           smbi    0
           phi     r8
           lbr     ext_cplp            ; loop back to copy rest of bytes

; ********************************
; *** List contents of library ***
; ********************************
cmd_list:  sep     scall               ; open the library file
           dw      open_lib
           db      0                   ; no special flags
           lbdf    liberr              ; jump if could not open library
lst_nmlp:  ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     0                   ; need to read 1 byte
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; read a byte
           dw      o_read
           lbdf    lst_done            ; jump if end of file
           glo     rc                  ; check read count
           lbz     lst_done            ; jump if end of file
           ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldn     rf                  ; get read byte
           lbz     lst_nmdn            ; jump if end of name found
           smi     01ah                ; check for XMODEM pad character
           lbz     lst_done            ; done if found
           ldn     rf                  ; recover byte
           sep     scall               ; otherwise display it
           dw      o_type
           lbr     lst_nmlp            ; and keep going
lst_nmdn:  sep     scall               ; move to next screen line
           dw      crlf
           ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     0                   ; need to read 5 bytes
           phi     rc
           ldi     5
           plo     rc
           sep     scall               ; read a byte
           dw      o_read
           lbdf    lst_done            ; jump if end of file
           glo     rc
           smi     5
           lbnz    lst_done
           ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           inc     rf                  ; move past flags byte
           lda     rf                  ; retrieve element size
           phi     r8
           lda     rf
           plo     r8
           lda     rf
           phi     r7
           lda     rf
           plo     r7
           ldi     0                   ; select seek from current
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; seek file position
           dw      o_seek
           lbr     lst_nmlp            ; process next entry
lst_done:  sep     scall               ; display a final CR/LF
           dw      crlf
           lbr     o_wrmboot           ; then back to Elf/OS

crlf:      ldi     10                  ; send a LF
           sep     scall
           dw      o_type
           ldi     13                  ; send a CF
           sep     scall
           dw      o_type
           sep     sret                ; return to calelr

; ****************************
; *** Add files to library ***
; ****************************
cmd_add:   ghi     rf                  ; transfer args address
           phi     ra
           glo     rf
           plo     ra
           sep     scall               ; open library file
           dw      open_lib
           db      5                   ; open for append, create if needed
           lbdf    liberr              ; jump if could not open library
add_loop:  ldn     ra                  ; get next byte from args
           lbz     add_done            ; jump if no more files to add
           ldi     low fname           ; where to put filename
           plo     r9
           sep     scall               ; get next filename
           dw      get_fname
           ldi     high fname          ; point to filename
           phi     rf
           ldi     low fname
           plo     rf
           sep     scall               ; write filename to lib file
           dw      o_write
           ldi     high fname          ; point to filename
           phi     rf
           ldi     low fname
           plo     rf
           ldi     low ffildes         ; point to 2nd file descriptor
           plo     rd
           ldi     4                   ; open at end
           plo     r7
           sep     scall               ; open the file
           dw      o_open
           lbdf    filerr              ; jump if could not open file
           ldi     low lfildes         ; get library file descriptor
           plo     rd                  ; into descriptor
           ldi     high buffer         ; where to write the bytes
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     0                   ; flags byte
           str     rf
           ldi     0                   ; 1 byte to write
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; write the bytes to lib file
           dw      o_write
           ldi     high ffildes        ; point to size field of file
           phi     rf
           ldi     low ffildes
           plo     rf
           ldi     0                   ; 4 bytes to write
           phi     rc
           ldi     4
           plo     rc
           sep     scall               ; write the bytes to lib file
           dw      o_write
           ldi     low ffildes         ; move file back to beginning
           plo     rd
           ldi     0 
           phi     r7
           plo     r7
           phi     r8
           plo     r8
           phi     rc
           plo     rc
           sep     scall               ; perform the seek
           dw      o_seek
copyloop:  ldi     low ffildes         ; need to read source file
           plo     rd
           ldi     high buffer         ; where to write the bytes
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     4                   ; read 1k
           phi     rc
           ldi     0
           plo     rc
           sep     scall               ; read from source file
           dw      o_read
           lbdf    copydone            ; jump if attempt to read past end
           glo     rc                  ; make sure bytes were read
           lbnz    copygo              ; jump if so
           ghi     rc                  ; check high byte as well
           lbnz    copygo
copydone:  ldi     low lfildes         ; point to library fildes
           plo     rd
           lbr     add_loop            ; see if more files to add
copygo:    ldi     low lfildes         ; library file descriptor
           plo     rd
           ldi     high buffer         ; point to read bytes
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; write to library file
           dw      o_write
           lbr     copyloop            ; loop back for more

add_done:  sep     scall               ; close the library file
           dw      o_close
           lbr     o_wrmboot           ; and return to Elf/OS

filerr:    ldi     high errmsg         ; point to usage message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall               ; and display it
           dw      o_msg
           ldi     low lfildes         ; point to library file descriptor
           plo     r9
           lbr     add_done            ; close library and exit

; *****************************************
; *** Get filename from args list       ***
; *** RA - Args list                    ***
; *** R9 - Where to put name            ***
; *** Returns: RC - count of characters ***
; ***               incl. terminator    ***
; *****************************************
get_fname: ldi     0                   ; setup count
           phi     rc
           plo     rc
fnamelp:   lda     ra                  ; get byte from args list
           str     r9                  ; store into destination
           inc     r9
           inc     rc                  ; increment character count
           smi     33                  ; check for whitespace
           lbdf    fnamelp             ; keep going until done
           dec     r9                  ; need to put proper terminator
           ldi     0
           str     r9
           dec     ra
ltrim:     ldn     ra                  ; move past following whitespace
           lbz     return              ; return if terminator found
           smi     33                  ; check for other whitespace
           lbdf    return              ; jump if not whitespace
           inc     ra                  ; move to next position
           lbr     ltrim               ; and keep trimming
return:    sep     sret                ; return to caller

errmsg:    db      'File not found',10,13,0
libmsg:    db      'Could not open library file',10,13,0
usage:     db      'Usage: lbr [a d e l] libname [file]',10,13,0

endrom:    equ     $

ldta:      ds      512
fdta:      ds      512
buffer:    ds      1024


