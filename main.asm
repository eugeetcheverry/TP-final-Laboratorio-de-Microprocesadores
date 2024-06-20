; Este es el main y los seteos iniciales q tenemos q hacer

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


.dseg
.org SRAM_START

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
	; Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)

	; Inicializo los puertos 
	ldi r16, 0x0f
	out DDRC, r16
	out DDRB, r16

	; Inicializo los punteros
	ldi XL, LOW(TABLA_COMPU)
	ldi XH, HIGH(TABLA_COMPU)

	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)

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
	sts USCR0A, r16
	ldi r16, 0b00000110
	sts USCR0C, r16
	ldi r16, 0b11011000
	sts USCR0B, r16  

	;Seteo interrupcion por: TIMER
	; Configuro el timer 0
	ldi r16, 0b10000010
	out TCCR0A, r16

	ldi r16, 237 ; top con prescaler de 1024
	out OCR0A, r16

	sei
