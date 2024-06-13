/*
USART
comunicacion asincronica
*baud rate: duracion de emision d ecada dato
-> ATMEGA328P 9600 bit/seg
*Tamano de datos: hast 9 bits
*Paridad: para verificar si hay errorer
*bits de inicio y bits de parada: mndo un 1 bit de inicio, mando un 0 bit de fin

Registros:
RESPETAR ORDEN
*UBRROL
*UBRROH
estos anteriorres marcan la velocidad a la que trabaja
En la datasheet esta la cuenta que se deben cargar en los registros
*USCROA -> casi todos los bits son de lectura, funcionan como flags
bit 7: se activa cuando se completa la recepcion de un dato y se almacena. se utiliza en interrupcion
bit 6: idem bit 7 pero con transmision.
bit 5: cuando esta seteado nos indica de udr0 estan vacios 
bit 4: se activa si hay error
bit 3: se pone en 1 si hay overflow
bit 2: indica error de paridad
bit 1: selecciona el modo de trabajo
bit 0: activa la comunicacion multiprocesador

*USCROC
bit 7 y 6: trabajan en conjunto para definir el modo
bit 5 y 4: seleccionan el tipo de paridad
bit 3: indica la cantidad de bits de parada 0 = 1bit, 1 = 2 bits
bit 2 y 1: seleccionan el tamano de los datos a transmitir se combinan cn otro bit de otro registro
bit 0: solo funcionan en modo sincronico
 
*USCROB
bit 7, 6 y 5: hanilitan interrupciones. por rx(recepcion completa), tx(transmisioncompleta)
interrupcion por overflow
bit 4 y 3: habilitacion de receptor y transmisor
bit2: bit para la combinacion de bit 2 y bit1 de usc0b
bit 1 y bit 0: son requeridos cuando se trabaja con 9 bits, se setean segun sea transmitido o recibido el noveno bit

*UDR0 -> Guarda el byte transmitido/recibido

 */ 
