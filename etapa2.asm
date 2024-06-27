.include "m328pdef.inc"

.def aux_joystick = r17
.def vleds = r18 

.dseg
.org SRAM_START

.cseg
.org 0X0000
	rjmp main

.org INT_VECTORS_SIZE

main:
	; Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)
	out sph, r16

	; Inicializo los puertos de salida
	ldi r16, 0x0f
	out DDRC, r16
	out DDRB, r16

	; Limpio contadores o cosas en general
	clr aux_joystick
	clr vleds

	ldi r16, 0b11110111
	sts ADCSRA, r16 

	ldi r16, 0x00
	sts ADCSRB, r16

	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 
	sei

eligiendo_numero:
	sbrc flag_int, 3 
	rcall incremento
	sbrc flag_int, 4
	rcall decremento
	rjmp eligiendo_numero

movimiento_joystick:
	lds aux_joystick, ADCH ;Valor del joystick
	cpi aux_joystick, 0b11110000
	in aux_SREG, sreg
	sbrs aux_SREG, 0
	ldi flag_int, 0b00001000
	cpi aux_joystick, 0b00001111
	in aux_SREG, sreg
	sbrc aux_SREG, 0
	ldi flag_int, 0b00010000
	ret

incremento:
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 9
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall paso_inicio_tabla
	ld r16, X
	sbrc r16, 0
	rcall muevo_puntero_inc
	out PORTB, contador_tabla_elegido
	ret

muevo_puntero_inc:
	cpi contador_tabla_elegido, 9
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_inicio_tabla
	inc contador_tabla_elegido
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_inc
	out PORTB, contador_tabla_elegido
	ret

paso_inicio_tabla:
	subi XL, 9
	sbci XH, 0
	clr contador_tabla_elegido
	ret


decremento:
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_fin_tabla
	dec contador_tabla_elegido
	sub XL, contador_tabla_elegido
	sbci XH, 0
	ld r16, X
	sbrc r16, 0
	rcall muevo_puntero_dec
	out PORTB, contador_tabla_elegido
	ret

paso_fin_tabla:
	ldi contador_tabla_elegido, 9
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ret

muevo_puntero_dec:
	dec contador_tabla_elegido
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_fin_tabla 
	sub XL, contador_tabla_elegido
	sbci XH, 0
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_dec
	ret











