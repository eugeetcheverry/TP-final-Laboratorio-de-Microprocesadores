 .include "m328pdef.inc"


 .def aux_SREG = r22
 .org SRAM_START

.cseg

.org 0X0000
	rjmp main

.org OC1Aaddr
	rjmp toggle_leds

main:
	;Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)
	out sph, r16

	;inicializo los puertos 
	ldi r16, 0b01011111
	out ddrc, r16

	ldi r16, 0b00001111
	out ddrb, r16 

	;Defino un contador
	clr r17 ; para ver si se llego al top
	ldi r18, 6 ; para ver si se iero 6 veces

inicializo_timer:
	cli
	ldi r16, 0b10000000
	sts TCCR1A, r16
	ldi r16, 0x0f ;para una frecuencia de 2hz
	sts OCR1AH, r16
	ldi r16, 0b00111100 ;para una frecuencia de 2hz
	sts OCR1AL, r16
	ldi r16, 0b00000010
	sts TIMSK1, r16 ; TIFR1 1
	sei
	ldi r16, 0b00001101
	sts TCCR1B, r16

wait: 
	rjmp wait

toggle_leds:
	sbic TIFR1, 1
	dec r18
	cpi r18, 0
	breq fin_timer
	ldi r20, 0b00001111
	out PINC, r20 
	out PINB, r20 ; haciendo con toggle
	reti
fin_timer:
	clr r16
	sts tccr1b, r16
	out PORTC, r16
	out PORTB, r16
fin_inter:
	reti




