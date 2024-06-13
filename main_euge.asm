.include "m328pdef.inc"

.def rflag = r17 ;0b000abcd
;a = etapa 1
;b = etapa 2
;c = etapa 3
;d = espera
.def rleds = r18 ; rrrr vvvv :nibble bajo leds verdes, nibble alto leds rojos
.def contador_tabla = r19
.def radc = r20

.dseg

.org SRAM_START

TABLA: .byte 10
NUM_ELEGIDO: .byte 2

.cseg

.org 0x0000
	rjmp main


;Sector de interrupciones por INT0
.org INT0addr
	rjmp interrupcion_push_btm

;Sector de interrupciones USART
.org URXCaddr
	rjmp interrupcion_etapa1

.org UTXCaddr
	rjmp transmision_de_dato

.org ADCCaddr
	rjmp joystick


.org INT_VECTORS_SIZE

main:
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)
	out sph, r16

	;inicializo los puertos 
	ldi r16, 0b01011111
	out ddrc, r16

	ldi r16, 0b00001111
	out ddrb, r16

	;Inicializo registros auxiliares
	clr rleds
	clr contador_tabla

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
	sts USCR0A, r16
	ldi r16, 0b00000110
	sts USCR0C, r16
	ldi r16, 0b11011000
	sts USCR0B, r16  

	;Seteo interrupcion por: TIMER
	
	sei

loop_wait:
	rcall chequeo_etapa
	rjmp loop_wait

chequeo_etapa:
	;sbic rflag, 0 ;No se si hace falta
	;rjmp etapa_1
	sbic rflag, 1
	rjmp eligiendo_numero
	sbic rflag, 2
	rjmp etapa_3
	sbic rflag, 3
	rjmp loop_wait
	rjmp loop_wait ;En el caso que no este nada seteado

eligiendo_numero:

	;Inicializo puntero a tabla
	ldi XL, low(TABLA)
	ldi XH, high(TABLA)

	rcall limpiar_tabla

	;Esto lo hago por primera vez
	;Los leds verdes inician apagados indicando que se arranca desde el número 0
	in r16, PINB
	andi r16, 0xf0
	out PORTB, r16
	;hasta aca
	;Los leds rojos inician apagados indicando que se arranca por el primer dígito
	in r16, PINC
	andi r16, 0xf0
	out PORTC, r16

	;Seteo interrupcion por: ADC
	cli ; Deshabilita las interrupciones 

	ldi r16, 0b11011111;Dejo deshabilitado el trigger
	sts ADCSRA, r16 ;Seteo tension de referencia y frecuencia de la señal ADC Clock es fosc/128

	ldi r16, 0x00
	sts ADCSRB, r16

	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 

	sei ;Habilito interrupciones globables

loop_eligiendo_numero:
	rjmp loop_eligiendo_numero

limpiar_tabla:
	ldi r16, 0
	ld X+, 0
	inc contador_tabla
	cpi contador_tabla, 9
	sbis sreg, 1
	rjmp limpiar_tabla
	clr contador_tabla
	ret

joystick:
	ld radc, ADCH
	cp radc, casi_max
	brsh inc_joystick
	cp radc, casi_min
	brlo dec_joystick
	rjmp fin_interrupcion

inc_joystick:
	inc contador_tabla
	st r16, X+
	sbic r16, 1
	rjmp fin_interrupcion
	inc contador_tabla
	cpi contador_tabla, 10
	breq 
	st r16, X+

dec_joystick:


interrupcion_push_btm: ;veo en que etapa estoy
	sbic rflag, 0
	rjmp interrupcion_etapa1
	rjmp interrupcion_etapa2

interrupcion_etapa1:
	sbic USRC0A, 7 ;FLAG RX
	rcall comparo_con_N
	rcall led_titilando ;espero 3 segundos con los leds titilando
	andi rflag, 0b00000010 ;paso a etapa 2
	sbic PIND, 2;veo si la interrupcion entro por int0
	rcall envio_N
	rjmp fin_interrupcion

envio_N:
	ldi r16, 78
	sts UDR0, r16
	ldi r16, 0x20; activo el bit UDRIE
	or USCR0B, r16; activo la interrupcion
	ret

comparo_con_N:
	lds r16, UDR0
	cpi r16, 78 ;Comparo con N
	sbic sreg, 2
	rjmp fin_interrupcion
	ret

leds_titilando:
	ret	

envio_j:
	ldi r16, 106
	sts UDR0, r16
	ldi r16, 0x20; activo el bit UDRIE
	or USCR0B, r16; activo la interrupcion
	ret

transmision_de_dato:
	rjmp fin_interrupcion

fin_interrupcion: 
	reti

