.include "m328pdef.inc"

.def flag_e = r17 ; Flag de estapa: 0b00000cba
;a = eligiendo contrincante
;b = eligiendo numero
;c = juego

.def flag_int = r18 ; Flag de interrupciones: 0b00fedcba
;a = int0
;b = usart rx
;c = usart tx
;d = adc_inc
;e = adc_dec

; Definimos registros 
.def contador_tabla_elegido = r19 ;
.def contador_tabla_compu = r20
.def num_elegido = r21 ; 
.def num_compu = r22
.def aux_SREG = r23
.def rleds = r24 ; funciona como contador de numeros mal posicionados
.def vleds = r25 ; funciona como contador de numeros bien posicionados
.def aux_joystick = r30
.def intentos = r31 ; Como no usamos el puntero Z podemos usar estos registros

.dseg
.org SRAM_START
TABLA_ELEGIDO: .byte 4
TABLA_COMPU: .byte 4
TABLA: .byte 10

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

;Sector de interrupción por TIMER 0
.org OVF0addr
	rjmp timer0_anti_rebote

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
	ldi flag_e, 0b00000001 ; Ponemos el flag en 1 para que entre a etapa de buscando contrincante
	clr r16

	;Seteo las interrupciones
	cli

	;Seteo interrupcion por: INT0
	ldi r16,  0x02 ;Por flanco descendente 
	sts EICRA, r16
	ldi r16, 0x01 ;Activo la interrupción
	out EIMSK, r16

	;Seteo interrupcion por: USART
	;Recibo datos y envio
	ldi r16, 12 ;Baudrate de 9600 para un micro de 1MHz
	sts UBRR0L, r16
	clr r16
	sts UBRR0H, r16
	ldi r16, 0b00100010
	sts UCSR0A, r16 
	ldi r16, 0b00000110
	sts UCSR0C, r16
	ldi r16, 0b11011000 
	sts UCSR0B, r16 

	;Seteo interrupción por timer 0
	ldi r16, 0b10000000 ;Modo normal, me baso en overflow
	out TCCR0A, r16
	ldi r16, 0x01
	sts TIMSK0, r16 ;Por interrupción
	ldi r16, 0x00
	out TCCR0B, r16 ; Todavía no está prendido el timer 0, porque no seteamos el prescaler

	;Seteo adc
	ldi r16, 0b11110111
	sts ADCSRA, r16 
	ldi r16, 0x00
	sts ADCSRB, r16 ;Todavía no está convirtiendo
	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 

	clr r16

	sei ; Habilito las interrupciones globales

; Loop vicioso que espera las inruupciones de cada etapa, en él, cada vez que se da una interrupción
; verifica en qué estado está el flag de etapa y entra a dicha etapa.
chequeo_etapa:
	sbrc flag_e, 0 
	rcall eligiendo_contrincante
	sbrc flag_e, 1
	rcall eligiendo_numero
	sbrc flag_e, 2
	rcall juego
	rjmp chequeo_etapa

;------------------------------------------------ETAPA 1: ELIGIENDO CONTRINCANTE----------------------------------------------------------------------
	/* En eligiendo etapa se puede tener dos tipos de interrupciones: recibo de datos por puerto serie o por pulsador. 
	Una vez que se entra a esta etapa se verifica por qué interrupción fue mirando el flag de interrupciones. Si fue por 
	el del pulsador, se envía una N por puerto serie y se pasa de etapa. Si fue por puerto serie, si se recibe una N salta 
	de etapa, sino sigue esperando*/
;-----------------------------------------------------------------------------------------------------------------------------------------------------

eligiendo_contrincante: ;Nos fijamos por qué tipo de interrupción se entró en esta etapa
	sbrc flag_int, 0
	rcall push_btm_etapa1
	sbrc flag_int, 1
	rcall usart_rx_etapa1
	ret

usart_rx_etapa1: ; Si fue por recibo de datos por puerto serie, se fija si es una N 
	clr flag_int
	lds r16, UDR0
	cpi r16, 78 ;Comparo con N en ascii 
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	rcall pasar_eligiendo_numero ; Si es una N pasamos a pasar_eligiendo_etapa
	ret

push_btm_etapa1: ; Si fue por pulsador, se envía una N y pasamos a pasar_eligiendo_etapa
	clr flag_int
	ldi r16, 78
	sts UDR0, r16
	rcall pasar_eligiendo_numero
	ret

pasar_eligiendo_numero: ; Antes de volver al loop chequeo_etapa, hacemos los arreglos para pasar de etapa
	clr flag_int ; Limpiamos el flag de interrupciones por las dudas
	ldi flag_e, 0b00000010 ; Cambiamos el flag de etapa a eligiendo numero 
	rcall leds_titilando ; Hacemos que los leds titilen 3 veces para indicar que sepasa de etapa
	ldi XL, low(TABLA) ; Preparamos las tabla que se van a usar en las siguientes tablas
	ldi XH, high(TABLA)
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	rcall limpiar_tabla ; Limpiamos la tabla y los registros a utilizar 
	clr aux_joystick
	clr vleds
	clr aux_SREG
	clr num_elegido
	clr flag_int
	clr contador_tabla_elegido
	clr rleds
	ret

;------------------------------------------------ETAPA 2: ELIGIENDO NUMERO----------------------------------------------------
/* En etapa eligiendo numero se activa el conversor ADC el cuaal convierte en todo momento, en el caso de sobrepasar un limite
impuesto se considerara que el usuario realizo un incremento y se activara el bit de incremento en el flag_int. De form analoga
para el decremento, se vera que al pasar un limite inferior se considerara que el usuario realizo un decremento y se actiavara 
el bit de decremento en el flag_int. De no ser un incremento o decremento no se hace nada.
En esta etapa solo se puede recibir interrupciones por INT0, cuando el usuario utilice el push-btm se seteara el bit de interrupcion
por push-btm en flg_int y al estar seteado el bit de etapa eligiendo numero en flag_e podemos identificar que se trata de la eleccion
de un numero, por lo que se guarda el numero guardado en el contador y se guarda en TABLA_ELEGIDO y a su vez colocamos un 1 en una tabla
auxiliar para, de esta forma, no obtener la opcion de legir un mismo numero dos veces.
Una vez que se termina de elegir los 4 digitos, se limpia la tabla auxiliar para luego usarla en la siguiente etapa y seteamos
en flag_e el bit de la etapa juego.
ADVERTENCIA: en esta etapa num_elegido esta cargado en 0 para utilizarlo en las sumas y restas
*/
;------------------------------------------------------------------------------------------------------------------------------

eligiendo_numero:
	rcall iniciar_adc 
	rcall movimiento_joystick ;En esta rutina se activan los flags de incremento o decremento 
	sbrc flag_int, 3 
	rcall incremento
	sbrc flag_int, 4
	rcall decremento
	sbrc flag_int, 0
	rcall elige_numero
	out PORTB, rleds
	out PORTC, vleds
	ret

iniciar_adc: ; Seteo adc
	ldi r16, 0b11110111 ;Seteo ADIE en 0, de esta forma convierte sin llamr a una interrupcion
	sts ADCSRA, r16 
	ldi r16, 0x00
	sts ADCSRB, r16
	ldi r16, 0b01100100 ;ADC4
	sts ADMUX, r16 
	ret

elige_numero:
	rcall deshabilitar_adc ; Al elegir un numero deshabilito el ADC
	clr flag_int
	cpi contador_tabla_elegido, 0
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	inc rleds
	sbrs aux_SREG, 1
	lsl rleds
	st Y+, vleds ;guardo el numero actual en tabla TABLA_ELEGIDO
	ldi r16, 1
	clc 
	add XL, vleds
	adc XH, num_elegido 
	st X, r16 ; cargo un 1 en la posicion del numero elegido
	ldi XL, LOW(TABLA)
	ldi XH, HIGH(TABLA)
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 4 ;Veo si es el ultimo digito
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall pasar_juego ;Si es el ultimo digito, la rutina pasar_juego setea todo para para a dicha etapa
	sbrc flag_e, 2 ; en el caso de que se haya habilitado el flag_e para etapa juego, saltamos a chequeo_etapa
	rjmp chequeo_etapa
	out PORTB, rleds ; Muestro el digito actual
	out PORTC, vleds ; Muestro el numero elegido
	ret
	

movimiento_joystick:
	lds r16, ADCSRA
	sbrs r16, 4 ;Espero hasta que la conversion se complete verificando ADIF
	rjmp movimiento_joystick
	lds aux_joystick, ADCH ;Cargo el valor leido
	rcall delay
	cpi aux_joystick, 0b11110000 ;Comparo si es un decremento
	in aux_SREG, sreg
	sbrs aux_SREG, 0
	ldi flag_int, 0b00001000 ;En el caso de ser decremento, activo el flag
	cpi aux_joystick, 0b00001111 ;Comparo si es un incremento
	in aux_SREG, sreg
	sbrc aux_SREG, 0
	ldi flag_int, 0b00010000 ; En el caso de ser incremento, activo el flag
	ldi r16, 0b11110111 
	sts ADCSRA, r16 
	out PORTC, vleds 
	ret

incremento:
	clr flag_int
	inc vleds ; Incremento el numero
	cpi vleds, 10 ;Comparo si llego a 10, en ese caso paso a 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi vleds, 0
	clc
	add XL, vleds ;Me muevo en TABLA hsta la posicion del numero actual
	adc XH, num_elegido 
	ld r16, X ;cargo en un auxiliar
	ldi XL, LOW(TABLA)
	ldi XH, HIGH(TABLA)
	cpi r16, 1 ; Si es igual a 1 signific que el numero ya fue elegido
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp incremento ;Si ya fue elegido, sigo avazando 
	ret

decremento:
	clr flag_int
	dec vleds
	cpi vleds, 0xff ;Comparo si llego a 0, en ese caso paso a 10
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	ldi vleds, 9
	clc
	add XL, vleds ;Me muevo en TABLA hasta la posicion del numero actual
	adc XH, num_elegido
	ld r16, X ; cargo en un auxiliar
	ldi XL, LOW(TABLA)
	ldi XH, HIGH(TABLA)
	cpi r16, 1 ; Comparo si es 1
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rjmp decremento ; Si es 1 indic que ya fue elegido, por lo que sigo incremento vleds
	ret


pasar_juego:	
	ldi flag_e, 0b00000100
	clr flag_int
	rcall leds_titilando
	rcall enviar_j ;Envio una j a la terminal
	rcall deshabilitar_adc ;Deshabilito ADC
	ldi XL, low(TABLA_COMPU) ;inicializo las correspondientes tablas de etapa juego
	ldi XH, high(TABLA_COMPU)
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	clr contador_tabla_elegido ;Limpio registros usados en etapa eligiendo numero
	clr contador_tabla_compu
	clr num_elegido
	clr num_compu
	clr vleds
	clr rleds
	clr r16
	clr aux_joystick
	out PORTB, r16 
	ret

deshabilitar_adc:
	clr r16
	sts ADCSRA, r16
	ret
enviar_j:
	ldi r16, 74
	sts UDR0, r16
	ret

;-----------------------------------------------ETAPA 3: JUEGO-----------------------------------------------------------
	/*En esta etapa tenemso tabién dos tipos de interrupciones, por pulsador y por recibo de datos por puerto serie
	Si es por pulsador, hay que ver si ganó el usuario. Si ya ganó, se manda una R por puerto serie y se pasa de etapa.
	Si no ganó no hacemos nada. Por otro lado, se puede recibir datos por puerto serie, tanto para recibir números 
	como para terminar el juego si, una vez que ya ganó el usuario envía una R.*/
;------------------------------------------------------------------------------------------------------------------------

juego: ;Nos fijamos por qué tipo de interrupción se entró en esta etapa
	sbrc flag_int, 0
	rcall push_btm_juego
	sbrc flag_int, 1
	rcall recibi_dato
	ret

; Si se presiona el pulsador antes de que el usuario gane no lo tenemos en cuenta
push_btm_juego:
	cpi vleds, 4 ; Verificamos si el jugador ya ganó, esto es cuando tiene los cuatro dígitos bien posicionados
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp retorno_push_btm_juego
	rcall paso_etapa1 ; Solamente se pasa de etapa cuando al pulsar el botón el jugador ya ganó
retorno_push_btm_juego:
	clr flag_int
	ret

; La otra interrupción puede ser por recibo de datos. Si el usuario ya ganó, solo interesa saber si se envía una R
; para pasar a termino_juego. 
recibi_dato:
	lds num_compu, UDR0
	clr flag_int
	cpi vleds, 4
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	rjmp termino_juego
	subi num_compu, '0' ; Si el jugador no ganó, se convierte de ASCII a número, y se guarda en la tabla
	st X+, num_compu
	inc contador_tabla_compu
	cpi contador_tabla_compu, 4
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	rcall numero_completo ; Una vez que se reciben los cuatro números, pasamos a numero_completo
retorno_recibi_dato:
	ret

termino_juego: ; Verificamos si una vez que ganamos se recibe una R
	cpi num_compu, 0x52 ; R en ascii
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp retorno_recibi_dato2
	rcall paso_etapa1 ; Si se recibió la R pasamos a paso_etapa1
retorno_recibi_dato2:
	ret

; Una vez que tenemos los cuatro números miramos si son válidos
numero_completo:
	ldi XL, LOW(TABLA_COMPU) 
	ldi XH, HIGH(TABLA_COMPU)
	ldi contador_tabla_compu, 0
loop_verifico_ascii:
	ld num_compu, X+
	cpi num_compu, 0 ; Verificamos si es menor a cero, no es número
	in aux_SREG, SREG
	sbrc aux_SREG, 0
	ldi r16, 0x01 ;Si no es número guardamos un 1 en r16 para verificar después
	cpi num_compu, 10 ; Verificamos si es mayor/igual a 10, no es número
	in aux_SREG, SREG
	sbrs aux_SREG, 0
	ldi r16, 0x01 ;Si no es número guardamos un 1 en r16 para verificar después
	inc contador_tabla_compu
	cpi contador_tabla_compu, 4
	in aux_SREG, SREG
	sbrc aux_SREG, 1
	rjmp chequeo_si_es_numero
	rjmp loop_verifico_ascii

chequeo_si_es_numero:
	cpi r16, 0x01 ; Si está en 1, significa que alguno de los datos recibidos no es un número
	brne todos_numeros ; Si son todos números, ya podemos empezar a comparar dígito a dígito
	clr r16
	ldi XL, LOW(TABLA_COMPU)
	ldi XH, HIGH(TABLA_COMPU)
	clr contador_tabla_compu ; Si no es número, volvemos a esperar datos y no se hace nada
	ret

todos_numeros:
	ldi XL, LOW(TABLA_COMPU)
	ldi XH, HIGH(TABLA_COMPU)
	clr contador_tabla_compu ; Cargo contador de la tabla que llega desde la compu para poder ir moviendome
	clr vleds
	clr rleds
loop_comparar_numeros: ; Comienzo la comparación
	ld num_compu, X+ ; Muevo una posición de la tabla de numero que entra por la compu
	inc contador_tabla_compu
	ldi contador_tabla_elegido, 0 ; Cargo contador de la tabla del numero elegido para poder ir moviendome
loop_tabla_elegido:
	ld num_elegido, Y+ ; Muevo una posición de la tabla de numero elegido 
	inc contador_tabla_elegido
	cp num_compu, num_elegido ; Comparo los números de ambas tablas
	breq numeros_iguales  ; Si son iguales salto a numero_iguales
	cpi contador_tabla_elegido, 4 ; Si el contador de la tabla Y llegó a 4, es porque se terminó y salto a termino_tabla_y
	breq termino_tabla_y
	rjmp loop_tabla_elegido ; Si no terminó la tabla y y no encontré números iguales, sigo recorriendo la tabla y
termino_tabla_y:
	cpi contador_tabla_compu, 4
	breq termino_tabla_x ; Si el contador de la tabla X llegó a 4, salto a termino_tabla_x
	ldi YL, LOW(TABLA_ELEGIDO) ; Reinicio el puntero Y
	ldi YH, HIGH(TABLA_ELEGIDO)
	rjmp loop_comparar_numeros ; Si no terminó la tabla X y se terminó la tabla y, sigo reccoriendo la tabla X y la tabla Y
numeros_iguales:
	cp contador_tabla_compu, contador_tabla_elegido ; Si los números son iguales, veo si están en la misma posición
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	inc rleds ; Si no están en la misma posición, incremento el contador rleds
	sbrc aux_SREG, 1
	inc vleds ; Si están en la misma posición incremento el contador vleds
	cpi contador_tabla_compu, 4
	breq termino_tabla_x ; Si se terminó la tabla X, salto a termino_tabla_x
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	rjmp loop_comparar_numeros
termino_tabla_x:
	inc intentos ; Incremento el contador de intentos 
	cpi vleds, 0b00000100
	breq gano ; Si el vleds llegó a 4 es porque ya ganó
	andi vleds, 0b00001111 ; Si no ganó muestro el contador de números correctos y bien posicionados y números correctos pero mal posicionados
	andi rleds, 0b00001111
	out PORTC, vleds
	out PORTB, rleds
	rjmp retorno_comparo_numeros ; Salto a retorno_comparo_numeros que vuelve a esperar recibir datos. Esto se hace hasta que el jugador gana
gano: 
	andi vleds, 0b00001111 ; Si ya ganó, se prenden todos los leds verdes 
	ldi aux_joystick, 0x0f
	out PORTC, aux_joystick
	out PORTB, intentos ; Por los leds rojos se saca la cantidad de intentos
retorno_comparo_numeros: ; Vuelvo a apuntar las tablas una vez que terminaron las comparaciones
	ldi XL, LOW(TABLA_COMPU)
	ldi XH, HIGH(TABLA_COMPU)
	ldi YL, LOW(TABLA_ELEGIDO)
	ldi YH, HIGH(TABLA_ELEGIDO)
	clr contador_tabla_compu
	clr contador_tabla_elegido
	clr r16
	ret

paso_etapa1: ; Para pasar de etapa cuando se recibe una R o se pulsa el botón una vez que ya ganó el jugador 
	ldi flag_e, 0b00000001 ; Pongo el flag de etapa en 1, etapa buscando contrincante
	clr vleds ; Limipio todos los registros
	clr rleds
	clr r16
	clr contador_tabla_elegido
	clr contador_tabla_compu
	clr num_elegido
	clr num_compu
	clr aux_SREG
	clr aux_joystick
	clr intentos
	rcall leds_titilando ; Llamo a leds titilando para indicar que se pasó de etapa
	out PORTB, vleds ; Dejo apagados los leds
	out PORTC, rleds
	ret

;-------------------------------------------------------------FUNCIONES AUXILIARES-----------------------------------------------------------
	/*Funciones que se usan varias veces en el código*/
;--------------------------------------------------------------------------------------------------------------------------------------------

leds_titilando:
	ldi r16, 0x00
	out PORTC, r16
	out PORTB, r16
	cli
	;ldi r16, 0b10000000
	ldi r16, 0x00
	sts TCCR1A, r16
	ldi r16, 0x01 ;para una frecuencia de 2hz -> 0.5ms
	sts OCR1AH, r16 ; Tengo un top de 489hz -> high(0000 0001)
	ldi r16, 0b11101001 ;
	sts OCR1AL, r16; Tengo un top de 489hz -> low(1110 1001)
	clr r16
	sts TIMSK1, r16 ; TIFR1 1
	sei
	ldi rleds, 6 ;Como llega al top cada 0.5ms, repito 6 veces para que dure 3s
	ldi vleds, 0b00001111
	ldi r16, 0b00001101
	sts TCCR1B, r16 
toggle_leds:
	sbis TIFR1, 1 ;Espero a que llegue al top
	rjmp toggle_leds
	dec rleds
	cpi rleds, 0 ; en el caso de llegar 0, apagmos el timer
	breq fin_timer
	out PINC, vleds 
	out PINB, vleds   
	sbi TIFR1, 1 ;Seteo en 1 el OCF1A para limpiarlo
	rjmp toggle_leds; haciendo con toggle
fin_timer:
	clr r16
	clr vleds
	clr rleds
	sts TCCR1B, r16
	out PORTC, r16
	out PORTB, r16
	ret

delay: ; como resulta de 3.8Hz (tener en cuenta que trabajamos con f_clock 1MHz)
	cli
	ldi intentos, 0b00000010 ; configurado en ctc
	sts TCCR2A, intentos
	ldi intentos, 255 ; top utilizado 
	sts OCR2A, intentos
	clr intentos
	sts TIMSK2, intentos ; TIFR1 1
	sei
	ldi intentos, 0b00000111 ;prescaler en 1024
	sts TCCR2B, intentos
	ldi intentos, 2
loop_delay:
	sbis TIFR2, 1 ; espero a que llegue al top
	rjmp loop_delay
	dec intentos
	cpi intentos, 0
	breq fin_delay
	sbi TIFR2, 1 ;Limpio OCF2A
	rjmp loop_delay
fin_delay:
	clr intentos
	sts TCCR2B, intentos
	ret

limpiar_tabla:
	ldi r16, 0
	st X+, r16
	inc contador_tabla_elegido
	cpi contador_tabla_elegido, 10
	in aux_SREG, SREG
	sbrs aux_SREG, 1
	rjmp limpiar_tabla
	clr contador_tabla_elegido
	ret

;---------------------------------------------------------------INTERRUPCIONES---------------------------------------------------------
	/*Acá se dan todas las interrupciones, en cada una de ellas ponemos el flag de interrupciones en el número que corresponde
	según los números que le indicamos. En el pulsador, tenemos que tener en cuneta el antirrebote.*/
;--------------------------------------------------------------------------------------------------------------------------------------
int0_push_btm:
	ldi r16, 0b00000101
	out TCCR0B, r16 ; Al setear acá el TCCR0B prendo el clock del timer 0 para el antirrebote
	reti ; Se espera que la siguiente interrupción sea la del timer 0

timer0_anti_rebote:
	sbic PIND, 2 ; Verifico que siga en el estado que queremos, es decir cuando es un corto a tierra
	rjmp timer0_apagar
	ldi flag_int, 0b00000001 ; Si es un corto a tierra, prendemos el flag de interrupciones por botón
timer0_apagar:
	ldi r16, 0x00
	out TCCR0B, r16 ; Apagamos el timer 0 para que no siga saltando por interrupciones
	reti

int_usart_rx:
	ldi flag_int, 0b00000010 ; Si se recibe un dato por puerto serie se prende el flag de interrupciones correspondiente
	reti

int_usart_tx: ; Dejamos la interrupcion de envío de datos
	reti
