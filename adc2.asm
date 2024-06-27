.include "m328pdef.inc"

.def aux_joystick = r17
.def contador_tabla_elegido = r18 
.def aux_SREG = r19
.def num_elegido = r30
.def flag_int = r31
.def rleds = r22
.def cont_dgt = r23
.def flag_e = r24
.def contador_tabla_compu = r25

.dseg
.org SRAM_START

TABLA_JUGANDO: .byte 4
TABLA_ELEGIDO: .byte 4

.cseg
.org 0X0000
	rjmp main

.org INT0addr
	rjmp int0_push_btm

/*.org OVF0addr
	rjmp timer0_anti_rebote*/

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
	ldi flag_e, 0b00000010

	ldi YL, low(TABLA_ELEGIDO)
	ldi YH, high(TABLA_ELEGIDO)

	ldi r16, 0b11110111
	sts ADCSRA, r16 

	ldi r16, 0x00
	sts ADCSRB, r16

	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 
	sei

chequeo_etapa:
	sbrc flag_e, 1
	rcall eligiendo_numero
	rjmp chequeo_etapa

eligiendo_numero:
	rcall movimiento_joystick
	sbrc flag_int, 3 
	rcall incremento
	sbrc flag_int, 4
	rcall decremento
	sbrc flag_int, 0
	rcall elige_numero
	out PORTC, rleds
	rjmp eligiendo_numero

elige_numero:
	clr flag_int
	cpi cont_dgt, 3
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp pasar_juego
	lsl rleds
	st Y+, contador_tabla_elegido
	inc cont_dgt
	;out PORTC, rleds
	;out PORTB, contador_tabla_elegido
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
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi contador_tabla_elegido, 0 ; ver que no pasa por el cero, puedo hacer rjmp
	rcall ya_se_eligio_inc
	out PORTC, contador_tabla_elegido
	ret

decremento:
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi contador_tabla_elegido, 9
	dec contador_tabla_elegido
	rcall ya_se_eligio_dec
	out PORTB, contador_tabla_elegido
	ret

ya_se_eligio_inc:
	ldi contador_tabla_compu, 0
loop_chequeo:
	st Y+, r16
	cp r16, contador_tabla_elegido
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	clr contador_tabla_elegido
	inc contador_tabla_compu
	cp contador_tabla_compu, cont_dgt
	in aux_SREG, sreg
	sbrs aux_SREG, 1 
	rjmp loop_chequeo
	sub YL, cont_dgt
	sbci YH, 0
	ret 

ya_se_eligio_dec:
	ldi contador_tabla_compu, 0
loop_chequeo_dec:
	st Y+, r16
	cp r16, contador_tabla_elegido
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	dec contador_tabla_elegido
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi contador_tabla_elegido, 9
	inc contador_tabla_compu
	cp contador_tabla_compu, cont_dgt
	in aux_SREG, sreg
	sbrs aux_SREG, 1 
	rjmp loop_chequeo_dec
	sub YL, cont_dgt
	sbci YH, 0
	ret 

pasar_juego:
	ldi r16, 0x0f
	out PORTC, r16
	out PORTB, r16
	clr flag_int
	rcall limpiar_tabla
	ldi flag_e, 0b00000100
	ldi XL, low(TABLA_JUGANDO)
	ldi XH, high(TABLA_JUGANDO)
	ldi YL, low(TABLA_ELEGIDO)
	ldi YH, high(TABLA_ELEGIDO)
	rcall deshabilito_adc;Apago contador
	ret

deshabilito_adc:
	clr r16
	sts ADCSRA, r16
	ret

limpiar_tabla:
	ldi r16, 0
	st X+, r16
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 9
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp limpiar_tabla
	clr contador_tabla_elegido
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
	ldi flag_int, 0x01
	reti

;SOLO LO NECESITAMOS PARA INT0 Y PINCHANGE
timer0_anti_rebote:
	sbic PIND, 2
	rjmp timer0_apagar
timer0_apagar:
	ldi r16, 0x00
	out TCCR0B, r16
fin_anti_rebote:
	reti 









