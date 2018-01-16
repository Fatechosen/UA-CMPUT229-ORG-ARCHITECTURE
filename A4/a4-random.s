#---------------------------------------------------------------
# Assignment:           4
# Due Date:             April 1, 2016
# Name:                 Chuan Yang
# Unix ID:              chuan1
# Lecture Section:      B1
# Lab Section:          H3
# Teaching Assistant(s):   ----- -----
#---------------------------------------------------------------
# run with command : xspim -mapped_io -exception_file lab4-exception.s -file a4-random.s
#---------------------------------------------------------------

################################################################################
# lab4_hanler: the main function in this assignment
#	       when we press a key, then jump to the do_keyboard
#	       when the timer arrives 300 ticks, jump to the do_timer
# data: *addr very important variable: save the addr of the string 
# do_keyboard: get the current address of the string from ADDR
#	       then save the pressed key in the string 
#	       then update the index of the string in addr now
# register usage :
#              t9 : the current address of string
#
# do_timer: when it gets to 300 ticks (or something else)
#	    print the whole string that user pressed
#	    then reset the address of the string
#	    then calculate the random number X (the algorithm is in the README)
# register usage :
#	       t0 : 0x0 use to reset every character of the string
#              t1 : max length of string 	    
#	       t2 : addr of the string
#	       
# reset, continue, back is all for reset the string and then calculate the X 
#
################################################################################


	.data
s_v0:     .word 0
s_a0:     .word 0
start_info: .asciiz "input string = '', x = 0 \n"
input_string: .asciiz "input string = '"
string: .space 61
	.align 2
print_x: .asciiz "', x = "
x: .word 0
addr: .word 0 		# use to save the addr of the string

	  .text
main:
	 la $t0, string			# get the address of input string
	 sw $t0, addr
	 # print the initial message
	 la $a0, start_info
	 li $v0, 4
	 syscall

	 # Enable keyboard interrupts	  
	 li	$a3, 0xffff0000        # base address of I/O
	 li	$s1, 2		       # $s1= 0x 0000 0002
	 sw 	$s1, 0($a3)	       # enable keyboard interrupts

	 # Enable global interrupts
	 li	$s1, 0x0000ff01	       # set IE= 1 (enable interrupts) , EXL= 0
	 mtc0	$s1, $12	       # SR (=R12) = enable bits

	 # Start timer
         mtc0  $0, $9                  # COUNT = 0
         addi  $t0, $0, 300            # $t0 = 50 ticks
         mtc0  $t0, $11                # CP0:R11 (Compare Reg.)= $t0

loop:	 beq  $t0,$t0, loop	       # infinite loop

        .globl  lab4_handler  
	.globl  addr 

lab4_handler:

	# Save $at, $v0, and $a0
	#
	.set noat
	move $k1 $at		# Save $at
	.set at
	sw   $v0 s_v0		# Not re-entrant and we can't trust $sp
	sw $a0, s_a0		# But we need to use these registers
	
	# Identify the interrupt source
	#
	mfc0   $k0, $13		# $k0 = Cause Reg (R13)

	srl    $a0, $k0, 11	# isolate IP3 (interrupt bit 1) (for keyboard)
	andi   $a0, 0x1
	bgtz   $a0, do_keyboard

	srl    $a0, $k0, 15	# isolate IP7 (interrupt bit 5) (for timer)
	andi   $a0, 0x1
	bgtz   $a0, do_timer

	b      lab4_handler_ret # ignore other interrupts

do_keyboard:
	lw  $t9, addr

	li  $t0, 0xffff0004		# get the information from the keyboard
	lb  $t1, 0($t0)
	
	sb  $t1, 0($t9)			# update the address of string
	addi $t9, $t9, 1
	sb  $t9, addr

	# li  $t0, 0xffff000c		# debug
	# sb  $t1, 0($t0) 	

	
	b      lab4_handler_ret

do_timer:
	la $t0, string			# get the address of input string
	sw $t0, addr

	la $a0, input_string		# print fixed information
	li $v0, 4
	syscall 
	
	la $a0, string			# print string
	li $v0, 4
	syscall 	

	la $a0, print_x
	li $v0, 4
	syscall
	
# reset s7 and the string
# and get the random X (sum of all chars then logical and with (127 = 0x7f = 0111 1111), and then -100 if its greater than 100)

	li  $t1, 61		# max length of string
	la  $t2, string		# get t2 = addr of string
	li  $t3, 0		
reset:	addi $t1, $t1, -1	# t1 -= 1
	bltz $t1, continue	# if t1<0, break
	li  $t0, 0x0
	lb  $t4, 0($t2)		# string[i] = 0x0(null)
	add $t3, $t3, $t4	
	sb  $t0, 0($t2)
	addi $t2, $t2, 1	# t2 += 1
	b reset			# loop

continue:
	andi $t3, $t3, 0x7f
	li   $t4, 0x64
	bge  $t3, $t4, minus_100

back:	addi $a0, $t3, 0	# print the random number that we get
	li $v0, 1
	syscall
	
	jal print_NL

	# Restart timer
	#
        mtc0  $0, $9                          # COUNT = 0
        addi  $t0, $0, 300                    # $t0 = 50 ticks
        mtc0  $t0, $11                        # CP0:R11 (Compare Reg.)= $t0

	b   lab4_handler_ret

minus_100:
	sub $t3, $t3, $t4
	b back


lab4_handler_ret:
	lw  $v0  s_v0		# restore $v0, $a0, and $at
	lw  $a0, s_a0

	.set noat
	move $at $k1		# Restore $at
	.set at

	mtc0 $0 $13		# Clear Cause register

	mfc0  $k0 $12		# Set Status register
	ori   $k0 0x1		# Interrupts enabled
	mtc0  $k0 $12
	
	eret			# exception return


print_NL:
          li   $a0, 0xA   # newline character
          li   $v0, 11
          syscall
          jr    $ra
# ------------------------------
