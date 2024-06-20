.include "m328pdef.inc"

.def flag_e = r17 ;0b0000dcba
;a = eligiendo contrincante
;b = eligiendo numero
;c = juego
;d = nada
.def flag_int = r18 ;0b00fedcba
;a = int0
;b = usart rx
;c = usart tx
;d = adc_inc
;e = adc_dec
;f = timer
.def contador_tabla = r19
.def cero = r20
.def rleds = r21
.def cont_dgt = r22
.def aux_joystick = r24
.def aux_SREG = r23

.equ max_valor = 1
.equ min_valor = 2
.dseg

.org SRAM_START

TABLA: .byte 10
NUM_ELEGIDO: .byte 4
NUM_JUGANDO: .byte 4

.cseg

.org 0X0000
	rjmp main

;Sector de interrupciones por INT0
.org INT0addr
	rjmp int_push_btm

;Sector de interrupciones USART
.org URXCaddr
	rjmp int_usart_rx

.org UTXCaddr
	rjmp int_usart_tx

.org ADCCaddr
	rjmp int_adc

.org INT_VECTORS_SIZE

main:
	;Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)

	;inicializo los puertos 
	ldi r16, 0b01011111
	out ddrc, r16

	ldi r16, 0b00001111
	out ddrb, r16

	
	;Seteo las interrupciones
	;Seteo interrupcion por: INT0
	ldi r16,  0x02 ;por flanco descendente 
	sts EICRA, r16
	ldi r16, 0x01
	sts EIMSK, r16

	;Seteo interrupcion por: USART
	;Recibo datos y envio
	ldi r16, 0x0c
	sts UBRR0L, r16
	clr r16
	sts UBRR0H, r16
	ldi r16, 0b00100010 ;velocidad doble
	sts UCSR0A, r16
	ldi r16, 0b00000110
	sts UCSR0C, r16
	ldi r16, 0b11011000
	sts UCSR0B, r16  

	sei

chequeo_etapa:
	sbrc flag_e, 0 
	rcall eligiendo_contrincante
	sbrc flag_e, 1
	rcall eligiendo_numero
	sbrc flag_e, 2
	rcall juego
	rjmp chequeo_etapa

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

;ETAPA: JUEGO-----------------------------------------------------------

;FUNCION LED_TITILANDO--------------------------------------------------
led_titilando:
	;timer de 3s por overflow, 
	cli
	ldi r16, 0b10000010
	out TCCR0A, r16
	ldi r16, 0b10000010
	out TCCR0A, r16

	ldi r16, 0xff ; top con prescaler de 1024
	out OCR0A, r16
	sei
	ldi r16, 0b00000101
	out TCCR0B, r16 ; cuando seteamos el prescaler 64 arranca a contar

	ldi r16, 95; contador
	ldi r17, 0b00001010
	out PORTC, r17
	out PORTB, r17
	
timer_loop_leds:
	sbic TIFR0, 0
	inc r16
	cpi r16, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp apago_timer_leds
	out PINC, r17
	out PIND, r17
	rjmp timer_loop

apago_timer_leds:
	clr r16
	out TCCR0B, r16
	out PORTC, r16
	out PORTB, r16
	ret

;FUNCION TIMER----------------------------------------------------------
timer_30ms:
	;Seteo interrupcion por: TIMER
	; Configuro el timer 0
	cli
	ldi r16, 0b10000010
	out TCCR0A, r16
	ldi r16, 237 ; top con prescaler de 1024
	out OCR0A, r16
	sei
	ldi r16, 0b00000101
	out TCCR0B, r16 ; cuando seteamos el prescaler 64 arranca a contar
timer_loop:
	sbis TIFR0, 1
	rjmp timer_loop
apago_timer:
	clr r16
	out TCCR0B, r16
	ret

;INTERRUPCIONES---------------------------------------------------------
int_int0:
	clr flag_int
	sbr flag_int, 0
	reti

int_usart_rx:
	clr flag_int
	sbr flag_int, 1
	reti

int_usart_tx:
	clr flag_int
	sbr flag_int, 2
	reti

int_adc:
	clr flag_int
	rjmp movimiento_joystick
	reti


int_timer:
	clr flag_int
	sbr flag_int, 4
	reti
