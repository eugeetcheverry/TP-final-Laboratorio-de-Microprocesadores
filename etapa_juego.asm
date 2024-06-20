.include "m328pdef.inc"

.def contador_tabla_elegido = r17
.def contador_tabla_compu = r18
.def num_elegido = r19
.def num_compu = r20
.def contador_numeros_bien_posicionados = r21
.def contador_numeros_mal_posicionados = r22
.def flag_e = r24
.def flag_int = r25
.def contador_datos_recibidos = r30

.dseg
.org SRAM_START
TABLA_ELEGIDO: .byte 4
TABLA_COMPU: .byte 4

.cseg
.org 0x0000
	rjmp main

.org INT_VECTORS_SIZE

main:
	; Inicializo el Stack Pointer
	ldi r16, LOW(RAMEND)
	out spl, r16
	ldi r16, HIGH(RAMEND)
	out sph, r16

	; Seteo las salidas
	ldi r16, 0x0f
	out DDRC, r16
	out PORTB, r16

	; Inicializo los punteros
	ldi XL, LOW(TABLA_COMPU)
	ldi XH, HIGH(TABLA_COMPU)

	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)

	clr contador_numeros_bien_posicionados
	clr contador_numeros_mal_posicionados
	clr r16

juego:
	sbrc flag_int, 0
	rcall push_btm_juego
	sbrc flag_int, 1
	rcall recibi_dato
	ret

; Acá tengo que comprobar que si terminó el juego recien ahi tiene q volver, sino me chupa un huevo el botón
push_btm_juego:
	cpi contador_numeros_bien_posicionados, 0b00000100
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
	cpi contador_numeros_bien_posicionados, 0b00000100
	in r23, SREG
	sbrc r23, 1
	rjmp termino_juego
	st X+, r16
	inc contador_datos_recibidos
	sbrc contador_datos_recibidos, 2
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
	inc contador_numeros_mal_posicionados
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	dec contador_tabla_compu
	breq termino_tabla_x
	rjmp loop_comparar_numeros
contadores_iguales:
	inc contador_numeros_bien_posicionados
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	dec contador_tabla_compu
	breq termino_tabla_x
	rjmp loop_comparar_numeros
termino_tabla_x:
	; reinicio ambos punteros
	ldi XL, LOW(TABLA_COMPU)
	ldi XH, HIGH(TABLA_COMPU)
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	; Incremento el contador de intentos
	inc r16
	; Veo si ya se terminó el juego
	cpi contador_numeros_bien_posicionados, 0b00000100
	breq gano
	;muestro resultados
	andi contador_numeros_bien_posicionados, 0b00001111
	andi contador_numeros_mal_posicionados, 0b00001111
	out PORTB, contador_numeros_bien_posicionados
	out PORTC, contador_numeros_mal_posicionados
	rjmp retorno_comparo_numeros
gano: 
	andi contador_numeros_bien_posicionados, 0b00001111
	out PORTB, contador_numeros_bien_posicionados
	out PORTC, r16
retorno_comparo_numeros:
	ret
