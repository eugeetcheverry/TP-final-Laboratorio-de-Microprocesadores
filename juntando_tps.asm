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
TABLA_COMPU: .byte 4

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

.org OVF0addr
	rjmp timer0_anti_rebote

/*.org OC1Aaddr
	rjmp toggle_leds*/

.org INT_VECTORS_SIZE

main:
	; Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)

	; Inicializo los puertos de salida
	ldi r16, 0x0f
	out DDRC, r16
	out DDRB, r16

	; Inicializo los puertos de entrada
	ldi r16, 0x00 
	out DDRD, r16
	;Activo el pull-up en INT0(PD2)
	ldi r16, 0b00000100
	out PORTD, r16


	; Limpio contadores o cosas en general
	clr rleds
	clr vleds
	ldi flag_e, 0b00000001
	clr r16

	;Seteo las interrupciones
	cli

	;Seteo interrupcion por: INT0
	ldi r16,  0x02 ;por flanco descendente 
	sts EICRA, r16
	ldi r16, 0x01
	out EIMSK, r16

	;Seteo interrupcion por: USART
	;Recibo datos y envio
	ldi r16, 103
	sts UBRR0L, r16
	clr r16
	sts UBRR0H, r16
	ldi r16, 0b0010_0010
	sts UCSR0A, r16 
	ldi r16, 0b0000_0110
	sts UCSR0C, r16
	ldi r16, 0b1101_1000 
	sts UCSR0B, r16 

	;Seteo interrupción por timer 0
	ldi r16, 0b10000000 ; uso modo normal, me baso en overflow
	out TCCR0A, r16
	ldi r16, 0x01
	sts TIMSK0, r16
	ldi r16, 0x00
	out TCCR0B, r16 ; Todavía no está prendido el timer 0, porque no seteamos el prescaler

	; Seteo adc
	ldi r16, 0b11110111
	sts ADCSRA, r16 
	ldi r16, 0x00
	sts ADCSRB, r16
	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 

	sei ; Habilito las interrupciones globales

chequeo_etapa:
	sbrc flag_e, 0 
	rcall eligiendo_contrincante
	sbrc flag_e, 1
	rcall eligiendo_numero
	/*sbrc flag_e, 2
	rcall juego*/
	rjmp chequeo_etapa

;------------------------------------------------ETAPA 1: ELIGIENDO CONTRINCANTE----------------------------------------------------------------------
eligiendo_contrincante:
	sbrc flag_int, 0
	rcall push_btm_etapa1
	sbrc flag_int, 1
	rcall usart_rx_etapa1
	ret

usart_rx_etapa1:
	clr flag_int
	lds r16, UDR0
	cpi r16, 78 ;Comparo con N
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	rcall pasar_eligiendo_numero
	ret

push_btm_etapa1:
	clr flag_int
	ldi r16, 78
	sts UDR0, r16
	rcall pasar_eligiendo_numero
	ret

pasar_eligiendo_numero:
	clr flag_int
	ldi flag_e, 0b00000010
	;rcall led_titilando
	;Inicializo puntero a tabla
	
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)

	ldi YL, low(TABLA_ELEGIDO)
	ldi YH, high(TABLA_ELEGIDO)

limpiar_tabla:
	ldi r16, 0
	st X+, r16
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp limpiar_tabla

	clr aux_joystick
	clr contador_tabla_elegido
	clr aux_SREG
	clr num_elegido
	clr cont_dgt
	clr flag_int
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

/*limpiar_tabla:
	ldi r16, 0
	st X+, r16
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp limpiar_tabla
	clr contador_tabla_elegido
	ret*/

;---------------------------------------------------------ETAPA 2: ELIGIENDO NUMERO--------------------------------------------
eligiendo_numero:
	rcall movimiento_joystick
	sbrc flag_int, 3 
	rcall incremento
	sbrc flag_int, 4
	rcall decremento
	sbrc flag_int, 0
	rcall elige_numero
	out PORTC, rleds
	out PORTB, contador_tabla_elegido
	rjmp eligiendo_numero

elige_numero:
	clr flag_int
	lsl rleds
	ldi r16, 1
	add XL, contador_tabla_elegido
	adc XH, num_elegido 
	st X, r16
	sub XL, contador_tabla_elegido
	sbci XH, 0
	mov r16, contador_tabla_elegido
	st Y+, r16
	inc cont_dgt
	cpi cont_dgt, 4
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall pasar_juego
	sbrc flag_e, 2
	rjmp chequeo_etapa
	out PORTC, rleds
	out PORTB, r16
	;sbrc cont_dgt, 2
	;rcall pasar_juego
	ret

movimiento_joystick:
	lds r16, ADCSRA
	sbrs r16, 4
	rjmp movimiento_joystick
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
	out PORTB, contador_tabla_elegido
	ret

incremento:
	clr flag_int
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi contador_tabla_elegido, 0
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ld r16, X
	sub XL, contador_tabla_elegido
	sbci XH, 0
	cpi r16, 1
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp incremento
	ret

decremento:
	clr flag_int
	dec contador_tabla_elegido
	cpi contador_tabla_elegido, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi contador_tabla_elegido, 10
	add XL, contador_tabla_elegido
	adc XH, num_elegido
	ld r16, X
	sub XL, contador_tabla_elegido
	sbci XH, 0
	cpi r16, 1
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp decremento
	ret


/*deshabilito_adc:
	clr r16
	sts ADCSRA, r16
	ret*/

pasar_juego:	
	ldi r16, 0x0f
	out PORTC, r16
	out PORTB, r16
	/*clr flag_int
	rcall limpiar_tabla
	ldi flag_e, 0b00000100
;	ldi XL, low(TABLA_JUGANDO)
;	ldi XH, high(TABLA_JUGANDO)
	ldi YL, low(TABLA_ELEGIDO)
	ldi YH, high(TABLA_ELEGIDO)
	rcall deshabilitar_adc;Apago contador*/
	ret

/*deshabilitar_adc:
	clr r16
	sts ADCSRA, r16
	ret*/
/*
limpiar_tabla:
	ldi r16, 0
	st X+, r16
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 9
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp limpiar_tabla
	clr contador_tabla_elegido
	ret*/
;-----------------------------------------------ETAPA 3: JUEGO-----------------------------------------------------------
/*juego:
	sbrc flag_int, 0
	rcall push_btm_juego
	sbrc flag_int, 1
	rcall recibi_dato
	ret

; Acá tengo que comprobar que si terminó el juego recien ahi tiene q volver, sino me chupa un huevo el botón
push_btm_juego:
	cpi vleds, 4
	in r23, SREG
	sbrs r23, 1
	rjmp retorno_push_btm_juego
	;VER QUE QUIERO Q HAGA CUANDO TERMINA EL JUEGO, ACA PRENDO TODOS LOS LEDS PARA VER
	ldi r16, 0x0f
	out PORTB, r16
	ldi flag_e, 0b00000001
	clr vleds
	clr rleds
retorno_push_btm_juego:
	clr flag_int
	ret

recibi_dato:
	lds num_compu, UDR0
	clr flag_int
	cpi vleds, 4
	in r23, SREG
	sbrc r23, 1
	rjmp termino_juego
	st X+, num_compu
	inc contador_tabla_compu
	cpi contador_tabla_compu, 4
	in r23, SREG
	sbrc r23, 1
	rcall numero_completo
retorno_recibi_dato:
	ret

termino_juego:
	cpi num_compu, 0x52 ; R en ascii
	in r23, SREG
	sbrs r23, 1
	rjmp retorno_recibi_dato2
	ldi r16, 0x0f
	out PORTB, r16
	ldi flag_e, 0b00000001
	clr vleds
	clr rleds
retorno_recibi_dato2:
	ret

; Compruebo que sea todo numeros ascii:
numero_completo:
	sub XL, contador_tabla_compu
	sbc XH, r31 ; muevo el puntero de la tabla compu para que este de nuevo al comienzo
	ldi contador_tabla_compu, 0
loop_verifico_ascii:
	ld num_compu, X+
	cpi num_compu, 48 ; 48 es el ascii para el
	in r23, SREG
	sbrc r23, 0
	ldi r16, 0x01
	cpi num_compu, 57 ; 58 es el ascii para el :, que va despues del 9
	in r23, SREG
	sbrs r23, 0
	ldi r16, 0x01
	inc contador_tabla_compu
	cpi contador_tabla_compu, 4
	in r23, SREG
	sbrc r23, 1
	rjmp chequeo_si_es_numero
	rjmp loop_verifico_ascii

chequeo_si_es_numero:
	cpi r16, 0x01 ; si esta clear es un numero
	brne todos_numeros
	clr r16
	sub XL, contador_tabla_compu
	sbc XH, r31 ; muevo el puntero de la tabla compu para que este de nuevo al comienzo
	clr contador_tabla_compu
	ret

todos_numeros:
	sub XL, contador_tabla_compu
	sbc XH, r31 ; muevo el puntero de la tabla compu para que este de nuevo al comienzo
	clr contador_tabla_compu ; Cargo contador de la tabla que llega desde la compu para poder ir moviendome
	clr vleds
	clr rleds
loop_comparar_numeros:
	ld num_compu, X+ ; Muevo una posición de la tabla de numero que entra por la compu
	inc contador_tabla_compu
	ldi contador_tabla_elegido, 0 ; Cargo contador de la tabla del numero elegido para poder ir moviendome
loop_tabla_elegido:
	ld num_elegido, Y+ ; Muevo una posición de la tabla de numero elegido 
	inc contador_tabla_elegido
	cp num_compu, num_elegido 
	breq numeros_iguales 
	cpi contador_tabla_elegido, 4
	breq termino_tabla_y
	rjmp loop_tabla_elegido
termino_tabla_y:
	; Reinicio el puntero Y
	cpi contador_tabla_compu, 4
	breq termino_tabla_x
	sub YL, contador_tabla_elegido
	sbc YH, r31
	rjmp loop_comparar_numeros
numeros_iguales:
	cp contador_tabla_compu, contador_tabla_elegido
	in r23, SREG
	sbrs r23, 1
	inc rleds
	sbrc r23, 1
	inc vleds
	cpi contador_tabla_compu, 4
	breq termino_tabla_x
	sub YL, contador_tabla_elegido
	sbc YH, r31
	rjmp loop_comparar_numeros
termino_tabla_x:
	inc r30 ; Incremento el contador de intentos 
	; Veo si ya se terminó el juego
	cpi vleds, 0b00000100
	breq gano
	andi vleds, 0b00001111
	andi rleds, 0b00001111
	out PORTB, vleds
	out PORTC, rleds
	rjmp retorno_comparo_numeros
gano: 
	andi vleds, 0b00001111
	out PORTB, vleds
	out PORTC, r30
retorno_comparo_numeros:
	sub XL, contador_tabla_compu
	sbc XH, r31 ; Este lo reinicio para que se pueda escribir de nuevo
	sub YL, contador_tabla_elegido
	sbc YH, r31
	clr contador_tabla_compu
	clr contador_tabla_elegido
	clr r16
	ret
	*/

;-------------------------------------------------------------FUNCIONES AUXILIARES-----------------------------------------------------------
/*led_titilando:
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
	ret

toggle_leds:
	sbic TIFR1, 1
	dec rleds
	cpi rleds, 0
	breq fin_timer
	ldi vleds, 0b00001111
	out PINC, vleds 
	out PINB, vleds ; haciendo con toggle
	reti
fin_timer:
	clr r16
	sts TCCR1B, r16
	out PORTC, r16
	out PORTB, r16
fin_inter:
	ldi r16, 0b00001000
	sts TCCR1B, r16
	reti*/
/*
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
*/;---------------------------------------------------------------INTERRUPCIONES---------------------------------------------------------
int0_push_btm:
	ldi r16, 0b00000101
	out TCCR0B, r16 ; Al setear acá el TCCR0B prendo el clock del timer 0 para el delay
	reti

;SOLO LO NECESITAMOS PARA INT0 
timer0_anti_rebote:
	sbic PIND, 2
	rjmp timer0_apagar
	ldi flag_int, 0b00000001
timer0_apagar:
	ldi r16, 0x00
	out TCCR0B, r16
	reti

int_usart_rx:
	ldi flag_int, 0b00000010
	reti

int_usart_tx:
	reti

