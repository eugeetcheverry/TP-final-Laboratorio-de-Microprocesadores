.include "m328pdef.inc"

.def flag_e = r17 ;0b00000cba
;a = eligiendo contrincante
;b = eligiendo numero
;c = juego

.def flag_int = r18 ;0b00fedcba
;a = int0
;b = usart rx
;c = usart tx
;d = adc_inc
;e = adc_dec
;f = timer

.def contador_tabla_elegido = r19 ; este funciona como contador_tabla
.def contador_tabla_compu = r20
.def num_elegido = r21 ; --> funciona como cero
.def num_compu = r22
.def aux_SREG = r23
.def rleds = r24 ; --> funciona como contador_numeros_mal_posicionados
.def vleds = r25 ; --> funciona como contador_numeros_bien_posicionados
.def aux_joystick = r30
.def cont_dgt = r31 ; ESTE CREO Q PODEMOS USAR EL MISMO PARA OTRO

.equ max_valor = 1
.equ min_valor = 2

.dseg
.org SRAM_START

TABLA: .byte 10
TABLA_ELEGIDO: .byte 4
TABLA_JUGANDO: .byte 4

.cseg
.org 0X0000
	rjmp main

;Sector de interrupciones por INT0
.org INT0addr
	rjmp int0_push_btm

;Sector de interrupciones USART
.org URXCaddr
	rjmp int_usart_rx

.org UTXCaddr
	rjmp int_usart_tx

.org ADCCaddr
	rjmp int_adc

.org INT_VECTORS_SIZE

main:
	; Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)

	; Inicializo los puertos 
	ldi r16, 0x0f
	out DDRC, r16
	out DDRB, r16

	; Limpio contadores o cosas en general
	clr rleds
	clr vleds
	clr flag_e
	clr r16

	;Seteo las interrupciones
	cli

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

;------------------------------------------------ETAPA 1: ELIGIENDO CONTRINCANTE----------------------------------------------------------------------
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

	ldi YL, low(TABLA_ELEGIDO)
	ldi YH, high(TABLA_ELEGIDO)

	rcall limpiar_tabla

	clr num_elegido
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
	st X+, r16
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 9
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp limpiar_tabla
	clr contador_tabla_elegido
	ret
;---------------------------------------------------------ETAPA 2: ELIGIENDO NUMERO--------------------------------------------
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
	mov r16, contador_tabla_elegido
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
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_inicio_tabla
	ld r16, X+
	sbrc r16, 0
	rcall muevo_puntero_inc
	ret

muevo_puntero_inc:
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_inicio_tabla
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_inc
	out PORTB, contador_tabla_elegido
	ret

paso_inicio_tabla:
	ldi contador_tabla_elegido, 0
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ret


decremento:
	dec contador_tabla_elegido
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_fin_tabla
	ld r16, -X
	sbrc r16, 0
	rcall muevo_puntero_dec
	out PORTB, contador_tabla_elegido
	ret

paso_fin_tabla:
	ldi contador_tabla_elegido, 11

muevo_puntero_dec:
	dec contador_tabla_elegido
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp paso_fin_tabla 
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)
	sub XL, contador_tabla_elegido
	sbc XH, num_elegido
	ld r16, X
	sbrc r16, 0
	rjmp muevo_puntero_dec
	ret

pasar_juego:
	clr flag_int
	rcall limpiar_tabla
	ldi flag_e, 0b00000100
	ldi XL, low(TABLA_JUGANDO)
	ldi XH, high(TABLA_JUGANDO)
	ldi YL, low(TABLA_ELEGIDO)
	ldi YH, high(TABLA_ELEGIDO)
	clr r16
	sts ADCSRA, r16;Apago contador
	ret

;-----------------------------------------------ETAPA 3: JUEGO-----------------------------------------------------------
juego:
	sbrc flag_int, 0
	rcall push_btm_juego
	sbrc flag_int, 1
	rcall recibi_dato
	ret

; Acá tengo que comprobar que si terminó el juego recien ahi tiene q volver, sino me chupa un huevo el botón
push_btm_juego:
	cpi vleds, 0b00000100
	in r23, SREG
	sbrc r23, 1
	rjmp retorno_push_btm_juego
	ldi flag_e, 0x00
	out PORTC, flag_e ; Apago los leds, uso este registro por comodidad
	out PORTB, flag_e
retorno_push_btm_juego:
	ret

; EN DATO RECIBIDO TENGO QUE CHEQUEAR QUE NO HAYA GANADO Y Q ESTE RECIBIENDO UNA R
recibi_dato:
	lds r16, UDR0
; Chequeo que no sea la R si ya termino el juego
	cpi vleds, 0b00000100
	in r23, SREG
	sbrc r23, 1
	rjmp termino_juego
	st X+, r16
	inc contador_tabla_compu
	sbrc contador_tabla_compu, 2
	rcall numero_completo
termino_juego:
	cpi r16, 82
	in r23, SREG
	sbrs r23, 1
	rjmp retorno_recibi_dato
	ldi flag_e, 0x00
	out PORTC, flag_e ; Apago los leds, uso este registro por comodidad
	out PORTB, flag_e
retorno_recibi_dato:
	ret

; Compruebo que sea todo numeros ascii:
numero_completo:
	ldi contador_tabla_compu, 4
loop_verifico_ascii:
	ld num_compu, X+
	cpi num_compu, 48 ; 48 es el ascii para el 0
	brlo no_es_numero
	cpi num_compu, 58 ; 58 es el ascii para el :, que va despues del 9
	brsh no_es_numero
	dec contador_tabla_compu
	breq comparar_numeros
	rjmp loop_verifico_ascii
no_es_numero:
	ret

comparar_numeros:
	ldi XL, LOW(TABLA_JUGANDO)
	ldi XH, HIGH(TABLA_JUGANDO)
	clr vleds
	clr rleds
	ldi contador_tabla_compu, 4 ; Cargo contador de la tabla que llega desde la compu para poder ir moviendome
loop_comparar_numeros:
	ld num_compu, X+ ; Muevo una posición de la tabla de numero que entra por la compu
	ldi contador_tabla_elegido, 4 ; Cargo contador de la tabla del numero elegido para poder ir moviendome
loop_tabla_elegido:
	ld num_elegido, Y+ ; Muevo una posición de la tabla de numero elegido 
	cp num_compu, num_elegido ; Comparo los números del numero q entra por la compu y el elegido
	breq numeros_iguales ; Si son iguales salto a otra función, sino decremento el contador de la tabla de numero elegido
	; veo si ya llegó a su fin, es decir q me movi 4 posiciones, y sino vuelvo al loop. Si ya llegó a su fin salto a 
	; termino_tabla_y q me reinicia el puntero en la tabla Y, decrementa el contador de la tabla x y vuelve a mover
	; una posición en la tabla x, antes fijandose si ya llegamos al fin de esa tabla.
	dec contador_tabla_elegido
	breq termino_tabla_y
	rjmp loop_tabla_elegido
termino_tabla_y:
	; Reinicio el puntero Y
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	dec contador_tabla_compu
	breq termino_tabla_x
	rjmp loop_comparar_numeros
numeros_iguales:
	cp contador_tabla_compu, contador_tabla_elegido
	breq contadores_iguales
	inc rleds
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	dec contador_tabla_compu
	breq termino_tabla_x
	rjmp loop_comparar_numeros
contadores_iguales:
	inc vleds
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	dec contador_tabla_compu
	breq termino_tabla_x
	rjmp loop_comparar_numeros
termino_tabla_x:
	; reinicio ambos punteros
	ldi XL, LOW(TABLA_JUGANDO)
	ldi XH, HIGH(TABLA_JUGANDO)
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	; Incremento el contador de intentos
	inc r16
	; Veo si ya se terminó el juego
	cpi vleds, 0b00000100
	breq gano
	;muestro resultados
	andi vleds, 0b00001111
	andi rleds, 0b00001111
	out PORTB, vleds
	out PORTC, rleds
	rjmp retorno_comparo_numeros
gano: 
	andi vleds, 0b00001111
	out PORTB, vleds
	out PORTC, r16
retorno_comparo_numeros:
	ret

;-------------------------------------------------------------FUNCIONES AUXILIARES-----------------------------------------------------------
;FUNCION LED_TITILANDO
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
	ldi num_compu, 0b00001010
	out PORTC, r17
	out PORTB, r17
	
timer_loop_leds:
	sbic TIFR0, 0
	inc r16
	cpi r16, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp apago_timer_leds
	out PINC, num_compu
	out PIND, num_compu
	rjmp timer_loop

apago_timer_leds:
	clr r16
	out TCCR0B, r16
	out PORTC, r16
	out PORTB, r16
	ret

;FUNCION TIMER
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

;---------------------------------------------------------------INTERRUPCIONES---------------------------------------------------------
int0_push_btm:
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