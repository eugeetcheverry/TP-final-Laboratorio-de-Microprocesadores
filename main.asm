.include "m328pdef.inc"

.def r_flag = r17 ;0b0000abc
.dseg

.org SRAM_START

.cseg

.org 0x0000
	rjmp main

.org INT0addr
	rjmp push_btm

;Sector de interrupciones


.org INT_VECTORS_SIZE

main:
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)
	out sph, r16

	;Seteo las interrupciones
	;Seteo interrupcion por: INT0
	ldi r16,  0x02 ;por flanco descendente 
	sts EICRA, r16
	ldi r16, 0x01
	sts EIMSK, r16

	;Seteo interrupcion por: USART
	;Seteo interrupcion por: ADC
	ldi r16, 0b00x00011 ;Setear bien el adlar
	sts ADMUX, r16
	ldi r16, 0b01
	sts ADCSRA, 
	;Seteo interrupcion por: TIMER

loop_wait:
	rjmp loop_wait

push_btm:
	reti
		

;MODULO: ELIGIENDO NUMERO

;MODULO: JUEGO

