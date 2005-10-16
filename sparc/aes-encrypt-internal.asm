C -*- mode: asm; asm-comment-char: ?C; -*-  
C nettle, low-level cryptographics library
C 
C Copyright (C) 2002, 2005 Niels M�ller
C  
C The nettle library is free software; you can redistribute it and/or modify
C it under the terms of the GNU Lesser General Public License as published by
C the Free Software Foundation; either version 2.1 of the License, or (at your
C option) any later version.
C 
C The nettle library is distributed in the hope that it will be useful, but
C WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
C or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
C License for more details.
C 
C You should have received a copy of the GNU Lesser General Public License
C along with the nettle library; see the file COPYING.LIB.  If not, write to
C the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
C MA 02111-1307, USA.


C	Arguments
define(<CTX>,	<%i0>)
define(<T>,	<%i1>)
define(<LENGTH>,<%i2>)
define(<DST>,	<%i3>)
define(<SRC>,	<%i4>)

C	AES state, two copies for unrolling

define(<W0>,	<%l0>)
define(<W1>,	<%l1>)
define(<W2>,	<%l2>)
define(<W3>,	<%l3>)

define(<X0>,	<%l4>)
define(<X1>,	<%l5>)
define(<X2>,	<%l6>)
define(<X3>,	<%l7>)

C	%o0-%03 are used for loop invariants T0-T3
define(<KEY>,	<%o4>)
define(<ROUND>, <%o5>)

C %g1 and %g2 are TMP1 and TMP2
		

C Registers %g1-%g3 and %o0 - %o5 are free to use.

C The sparc32 stack frame looks like
C
C %fp -   4: OS-dependent link field
C %fp -   8: OS-dependent link field
C %fp -  24: tmp, uint32_t[4]
C %fp -  40: wtxt, uint32_t[4]
C %fp - 136: OS register save area. 
define(<FRAME_SIZE>, 136)

	.file "aes-encrypt-internal.asm"

	C _aes_encrypt(struct aes_context *ctx, 
	C	       const struct aes_table *T,
	C	       unsigned length, uint8_t *dst,
	C	       uint8_t *src)

	.section	".text"
	.align 16
	.proc	020
	
PROLOGUE(_nettle_aes_encrypt)

	save	%sp, -FRAME_SIZE, %sp
	cmp	LENGTH, 0
	be	.Lend

	C	Loop invariants
	add	T, AES_TABLE0, T0
	add	T, AES_TABLE1, T1
	add	T, AES_TABLE2, T2
	add	T, AES_TABLE3, T3

.Lblock_loop:
	C  Read src, and add initial subkey
	add	CTX, AES_KEYS, KEY
	AES_LOAD(0, SRC, KEY, W0)
	AES_LOAD(1, SRC, KEY, W1)
	AES_LOAD(2, SRC, KEY, W2)
	AES_LOAD(3, SRC, KEY, W3)

	C	Must be even, and includes the final round
	ld	[AES_NROUNDS + CTX], ROUND
	add	SRC, 16, SRC
	add	KEY, 16, KEY

	srl	ROUND, 1, ROUND
	C	Last two rounds handled specially
	sub	ROUND, 1, ROUND
.Lround_loop:
	C The AES_ROUND macro uses T0,... T3
	C	Transform W -> X
	AES_ROUND(0, W0, W1, W2, W3, KEY, X0)
	AES_ROUND(1, W1, W2, W3, W0, KEY, X1)
	AES_ROUND(2, W2, W3, W0, W1, KEY, X2)
	AES_ROUND(3, W3, W0, W1, W2, KEY, X3)

	C	Transform X -> W
	AES_ROUND(4, X0, X1, X2, X3, KEY, W0)
	AES_ROUND(5, X1, X2, X3, X0, KEY, W1)
	AES_ROUND(6, X2, X3, X0, X1, KEY, W2)
	AES_ROUND(7, X3, X0, X1, X2, KEY, W3)

	subcc	ROUND, 1, ROUND
	bne	.Lround_loop
	add	KEY, 32, KEY

	C	Penultimate round
	AES_ROUND(0, W0, W1, W2, W3, KEY, X0)
	AES_ROUND(1, W1, W2, W3, W0, KEY, X1)
	AES_ROUND(2, W2, W3, W0, W1, KEY, X2)
	AES_ROUND(3, W3, W0, W1, W2, KEY, X3)

	add	KEY, 16, KEY
	C	Final round
	AES_FINAL_ROUND(0, T, X0, X1, X2, X3, KEY, DST)
	AES_FINAL_ROUND(1, T, X1, X2, X3, X0, KEY, DST)
	AES_FINAL_ROUND(2, T, X2, X3, X0, X1, KEY, DST)
	AES_FINAL_ROUND(3, T, X3, X0, X1, X2, KEY, DST)

	subcc	LENGTH, 16, LENGTH
	bne	.Lblock_loop
	add	DST, 16, DST

.Lend:
	ret
	restore
EPILOGUE(_nettle_aes_encrypt)

C Some stats from adriana.lysator.liu.se (SS1000$, 85 MHz), for AES 128

C A:	nettle-1.13 C-code
C B:	nettle-1.13 assembler
C C:	New C-code
C D:	New assembler, first correct version
C E:	New assembler, with basic scheduling of AES_ROUND.
	
C	MB/s	cycles/block
C A	1.2	1107
C B	2.3	572
C C	2.1	627
C D	1.8	722
C E	2.6	496
