;ETAPA: ELIGIENDO CONTRINCANTE----------------------------------------------------------------------
eligiendo_contrincante:
	sbrc flag_int, 0
	rcall push_btm_etapa1
	sbrc flag_int, 1
	rcall usart_rx_etapa1
	ret

usart_rx_etapa1:
	lds r16, UDR0
	cpi r16, 78 ;Comparo con N
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	rcall pasar_eligiendo_numero
	ret

push_btm_etapa1:
	ldi r16, 78
	sts UDR0, r16
	rcall pasar_eligiendo_numero
	ret

pasar_eligiendo_numero:
	clr flag_int
	ldi flag_e, 0b00000010
	rcall led_titilando
	;Inicializo puntero a tabla
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)

	ldi YL, low(NUM_ELEGIDO)
	ldi YH, high(NUM_ELEGIDO)

	rcall limpiar_tabla

	clr cero
	clr cont_dgt
	ldi rleds, 0b00000001
	;Seteo interrupcion por: ADC
	cli ; Deshabilita las interrupciones 

	ldi r16, 0b11011111;Dejo deshabilitado el trigger
	sts ADCSRA, r16 ;Seteo tension de referencia y frecuencia de la señal ADC Clock es fosc/128

	ldi r16, 0x00
	sts ADCSRB, r16

	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 
	sei

	ret

limpiar_tabla:
	ldi r16, 0
	st X+, 0
	inc contador_tabla
	cpi contador_tabla, 9
	in aux_SREG, sreg
	sbrs aux_SREG, 1
	rjmp limpiar_tabla
	clr contador_tabla
	ret

