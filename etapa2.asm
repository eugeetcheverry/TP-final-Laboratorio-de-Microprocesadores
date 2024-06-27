.include "m328pdef.inc"

.def aux_joystick = r17
.def contador_tabla_elegido = r18 
.def aux_SREG = r19
.def num_elegido = r20
.def flag_int = r21
.def rleds = r22
.def cont_dgt = r23

.dseg
.org SRAM_START

.cseg
.org 0X0000
	rjmp main

.org INT0addr
	rjmp int0_push_btm

.org OVF0addr
	rjmp timer0_anti_rebote

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

	;Inicializo los puertos de entrada
	ldi r16, 0x00 
	out DDRD, r16
	;Activo el pull-up en INT0(PD2)
	ldi r16, 0b00000100
	out PORTD, r16

	;Seteo interrupcion por: INT0
	ldi r16,  0x02 
	sts EICRA, r16
	ldi r16, 0x01
	out EIMSK, r16

	; Limpio contadores o cosas en general
	clr aux_joystick
	clr aux_joystick
	clr contador_tabla_elegido 
	clr aux_SREG
	clr num_elegido
	clr flag_int
	clr cont_dgt
	ldi rleds, 0b00000001

	ldi r16, 0b11110111
	sts ADCSRA, r16 

	ldi r16, 0x00
	sts ADCSRB, r16

	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 
	sei

eligiendo_numero:
	rcall movimiento_joystick
	sbrc flag_int, 3 
	rcall incremento
	sbrc flag_int, 4
	rcall decremento
	sbrc flag_int, 0
	rcall elige_numero
	rjmp eligiendo_numero

elige_numero:
	lsl rleds
	mov r16, contador_tabla_elegido
	st Y+, r16
	inc cont_dgt
	out PORTC, rleds
	;sbrc cont_dgt, 2
	;rcall pasar_juego
	ret

movimiento_joystick:
	lds aux_joystick, ADCH ;Valor del joystick
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	rcall retardo_Tacm
	cpi aux_joystick, 0b11110000
	in aux_SREG, sreg
	sbrs aux_SREG, 0
	ldi flag_int, 0b00001000
	cpi aux_joystick, 0b00001111
	in aux_SREG, sreg
	sbrc aux_SREG, 0
	ldi flag_int, 0b00010000
	ldi r16, 0b11110111
	sts ADCSRA, r16 
	ret

incremento:
	cpi contador_tabla_elegido, 9
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall paso_inicio_tabla
	inc contador_tabla_elegido
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ld r16, X
	sbrc r16, 0
	rcall muevo_puntero_inc
	out PORTB, contador_tabla_elegido
	ret

muevo_puntero_inc:
	cpi contador_tabla_elegido, 9
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall paso_inicio_tabla
	inc contador_tabla_elegido
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_inc
	out PORTB, contador_tabla_elegido
	ret

paso_inicio_tabla:
	sub XL, contador_tabla_elegido
	sbci XH, 0
	clr contador_tabla_elegido
	ret

decremento:
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall paso_fin_tabla
	dec contador_tabla_elegido
	sub XL, contador_tabla_elegido
	sbci XH, 0
	ld r16, X
	sbrc r16, 0
	rcall muevo_puntero_inc
	out PORTB, contador_tabla_elegido
	ret

paso_fin_tabla:
	ldi contador_tabla_elegido, 9
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ret


retardo_Tacm:
	eor r21 , r21
loop_retardo_t2cm:
	inc r21
	eor r20 , r20

loop_retardo_t1cm1:
	inc r20
	cpi r20 , 0xff
	brne loop_retardo_t1cm1

	cpi r21 , 0xff
	brne loop_retardo_t2cm
	ret

int0_push_btm:
	ldi r16, 0b00000100
	out TCCR0B, r16 ; Al setear acá el TCCR0B prendo el clock del timer 0 para el delay
	reti

;SOLO LO NECESITAMOS PARA INT0 Y PINCHANGE
timer0_anti_rebote:
	sbic PIND, 2
	rjmp timer0_apagar
	ldi flag_int, 0x01
timer0_apagar:
	ldi r16, 0x00
	out TCCR0B, r16
fin_anti_rebote:
	reti












