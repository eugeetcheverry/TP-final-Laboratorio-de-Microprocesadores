
;ETAPA: ELIGIENDO NUMERO--------------------------------------------
eligiendo_numero:
	out PORTC, rleds
	sbrc flag_int, 0
	rcall elige_numero
	sbrc flag_e, 2
	rcall chequeo_etapa
	sbrc flag_int, 3 
	rcall incremento
	sbrc flag_int, 4
	rcall decremento
	ret

elige_numero:
	lsr rleds
	mov r16, contador_tabla
	st Y+, r16
	rcall movimiento_joystick
	inc cont_dgt
	sbrc cont_dgt, 2
	rcall pasar_juego
	ret

movimiento_joystick:
	lds aux_joystick, ADCH ;Valor del joystick
	cpi aux_joystick, max_valor
	in aux_SREG, sreg
	sbrs aux_SREG, 0 ;busque que testea brsh y es el glag del carry
	rcall es_inc
	cpi aux_joystick, min_valor
	in aux_SREG, sreg
	sbrc aux_SREG, 0 ;Busque que testea brlo y es el flag del carry
	rcall es_dec
	reti

es_inc:
	;Espero 30ms para ver si hay un deceremento
	rcall timer_30ms
	lds aux_joystick, ADCH
	cpi aux_joystick, max_valor
	in aux_SREG, sreg
	sbrc aux_SREG, 0 ; si es menor esta limpio el flag del carry
	sbr flag_int, 3
	ret

es_dec:
	;Espero 30ms para ver si hay un deceremento
	rcall timer_30ms
	lds aux_joystick, ADCH
	cpi aux_joystick, min_valor
	in aux_SREG, sreg
	sbrs aux_SREG, 0 ; si es menor esta limpio el flag del carry
	sbr flag_int, 4
	ret
	

incremento:
	inc contador_tabla
	cpi contador_tabla, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_inicio_tabla
	ld r16, X+
	sbrc r16, 0
	rcall muevo_puntero_inc
	ret

muevo_puntero_inc:
	inc contador_tabla
	cpi contador_tabla, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_inicio_tabla
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)
	add XL, contador_tabla
	adc XH, cero
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_inc
	out PORTB, contador_tabla
	ret

paso_inicio_tabla:
	ldi contador_tabla, 0
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)
	add XL, contador_tabla
	adc XH, cero
	ret


decremento:
	dec contador_tabla
	cpi contador_tabla, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_fin_tabla
	ld r16, -X
	sbrc r16, 0
	rcall muevo_puntero_dec
	out PORTB, contador_tabla
	ret

paso_fin_tabla:
	ldi contador_tabla, 11

muevo_puntero_dec:
	dec contador_tabla
	cpi contador_tabla, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_fin_tabla 
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)
	sub XL, contador_tabla
	sbc XH, cero
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_dec
	ret

pasar_juego:
	clr flag_int
	rcall limpiar_tabla
	ldi flag_e, 0b00000100
	ldi XL, low(NUM_JUGANDO)
	ldi XH, high(NUM_JUGANDO)
	ldi YL, low(NUM_ELEGIDO)
	ldi YH, high(NUM_ELEGIDO)
	clr r16
	sts ADCSRA, r16;Apago contador
	ret

