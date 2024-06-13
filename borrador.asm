/*recepcion_de_dato:
	lds r16, UDR0
	cpi r16, 78 ;Comparo con N
	brne fin_interrupcion; Si no es una N, sigo con el juego
	;espero 3 segundos con los leds titilando
	rcall led_titilando
	;paso a etapa 2
	andi rflag, 0b00000100
	rjmp fin_interrupcion
;Podria poner estas dos funciones juntas, ya que hacen parcticamnete lo mismo
push_btm:
	;espero 3 segundos con los leds titilando
	rcall led_titilando
	;paso a etapa 2
	andi rflag, 0b00000100
	rjmp fin_interrupcion*/ 

/* 
eligiendo_numero:
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
*/
