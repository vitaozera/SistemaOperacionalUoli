.org 0x0
.section .iv, "a"

@@@@@@@@@@@@@@
@ CONSTANTES @
@@@@@@@@@@@@@@

@ Início do programa do usuário
.set USER_PROGRAM,               0x77802000

@ Quantidades de ciclos necessários para
@ incrementar o contador do relogio
.set TIME_SZ,                    0x7000

@ Números das Syscalls
.set SVC_READ_SONAR_CODE,                  16
.set SVC_REGISTER_PROXIMITY_CALLBACK_CODE, 17
.set SVC_SET_MOTOR_SPEED_CODE,             18
.set SVC_SET_MOTORS_SPEED_CODE,            19
.set SVC_GET_TIME_CODE,                    20
.set SVC_SET_TIME_CODE,                    21
.set SVC_SET_ALARM_CODE,                   22
.set SVC_SET_IRQ_MODE_CODE,				   99

@ Constantes para os enderecos do TZIC
.set TZIC_BASE,                  0x0FFFC000
.set TZIC_INTCTRL,               0x0
.set TZIC_INTSEC1,               0x84
.set TZIC_ENSET1,                0x104
.set TZIC_PRIOMASK,              0xC
.set TZIC_PRIORITY9,             0x424

@ Constantes para os enderecos do GPT
.set GPT_CR,                     0x53FA0000
.set GPT_PR,                     0x53FA0004
.set GPT_OCR1,                   0x53FA0010
.set GPT_IR,                     0x53FA000C
.set GPT_SR,                     0x53FA0008

@ Constantes para os enderecos do GPIO
.set GPIO_DR,                    0x53F84000
.set GPIO_GDIR,                  0x53F84004
.set GPIO_PSR,                   0x53F84008

@ Constantes para os enderecos das pilhas
.set STACK_USER,                 0x78800000
.set STACK_SUPER,                0x78830000
.set STACK_IRQ,                  0x78860000

@ Constantes dos motores
.set MOTOR_0_MASK,               0b00000001111111000000000000000000
.set MOTOR_1_MASK,               0b11111110000000000000000000000000
.set MOTOR_0_AND_1_MASK,         0b11111111111111000000000000000000

@ Constantes do acesso as estruturas das callbacks
.set ID_OFFSET,					 0x00
.set DIST_THRESHOLD_OFFSET,		 0x04
.set FUNCTION_ADDRESS_OFFSET,	 0x08
.set CALLBACK_STRUCT_SIZE,		 0x0C
.set CALLBACK_ARRAY_SIZE,		 0x60
.set EMPTY_REGISTER,			 0x10

@ Constantes de acesso as estruturas dos alarms
.set ALARMS_STRUCT_SIZE,		0x08
.set FUNCTION_ALARM_OFFSET,		0x00
.set TIME_ALARM_OFFSET,			0x04
.set EMPTY_ALARM,				0x00

@ Valores maximos de alarmes e callbacks
.set MAX_ALARMS,				 0x08
.set MAX_CALLBACKS,				 0x08

@ Valor maximo da velocidade do motor
.set MAX_MOTOR_SPEED,			 0b111111

@ Constante de atraso de 15 ms
.set ATRASO_15MS,				 0x100

_start:

@@@@@@@@@@@@@@@@@@@@@@@@@
@ VETOR DE INTERRUPCOES @
@@@@@@@@@@@@@@@@@@@@@@@@@

interrupt_vector:

	b RESET_HANDLER

.org 0x08
	b SOFTWARE_INTERRUPTION

.org 0x18
	b IRQ_HANDLER

.org 0x100

.text
@@@@@@@@@@@@@@@@@@@@@@@@
@ RESET HANDLER E BOOT @
@@@@@@@@@@@@@@@@@@@@@@@@

@ Zerar contador
	ldr r0, =CONTADOR
	mov r1, #0x0
	str r1, [r0]

RESET_HANDLER:
	@ Set interrupt table base address on coprocessor 15.
	ldr r0, =interrupt_vector
	mcr p15, 0, r0, c12, c0, 0

SET_STACK:
	@ Configura a stack do modo USER,
	@ mudando o modo para SYSTEM.
	msr CPSR_c, #0x1F
	ldr sp, =STACK_USER

	@ Configura a stack do modo IRQ,
	@ mudando o modo para IRQ
	msr CPSR_c, #0x12
	ldr sp, =STACK_IRQ

	@ Configura a stack do modo SUPERVISOR
	@ Volta para SUPERVISOR
	msr CPSR_c, #0x13
	ldr sp, =STACK_SUPER

SET_TZIC:
	@ Liga o controlador de interrupcoes
	@ R1 <= TZIC_BASE

	ldr r1, =TZIC_BASE

	@ Configura interrupcao 39 do GPT como nao segura
	mov r0, #(1 << 7)
	str r0, [r1, #TZIC_INTSEC1]

	@ Habilita interrupcao 39 (GPT)
	@ reg1 bit 7 (gpt)

	mov r0, #(1 << 7)
	str r0, [r1, #TZIC_ENSET1]

	@ Configure interrupt39 priority as 1
	@ reg9, byte 3

	ldr r0, [r1, #TZIC_PRIORITY9]
	bic r0, r0, #0xFF000000
	mov r2, #1
	orr r0, r0, r2, lsl #24
	str r0, [r1, #TZIC_PRIORITY9]

	@ Configure PRIOMASK as 0
	eor r0, r0, r0
	str r0, [r1, #TZIC_PRIOMASK]

	@ Habilita o controlador de interrupcoes
	mov r0, #1
	str r0, [r1, #TZIC_INTCTRL]

	@ instrucao msr - habilita interrupcoes
	msr  CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled

SET_GPT:
	@ Escreve em R0 o endereco do GPT_CR (control register)
	ldr r0, =GPT_CR
	@ Grava no GPT_CR o valor 0x00000041 habilitando o clock_src para periferico
	mov r1, #0x00000041
	str r1, [r0]

	@ Zera o prescaler GPT_PR
	mov r0, #0x0
	ldr r1, =GPT_PR
	str r0, [r1]

	@ Valor de contagem no GPT_OCR1
	mov r0, #TIME_SZ
	ldr r1, =GPT_OCR1
	str r0, [r1]

	@ Marca interesse em interrupcoes do tipo Output "Compare Channel 1"
	mov r0, #0x1
	ldr r1, =GPT_IR
	str r0, [r1]

SET_GPIO:
	@ Configura o GDIR do GPIO, definindo entradas e saida
	@ bit a bit
	ldr r0, =0b11111111111111000000000000111110
	ldr r1, =GPIO_GDIR
	str r0, [r1]
	
SET_CALLBACK_ARRAY:
	@ Inicializa vetor de callbacks
	ldr r5, =CALLBACKS_ARRAY
	ldr r6, =CALLBACK_STRUCT_SIZE
	ldr r7, =CALLBACK_ARRAY_SIZE
	add r7, r5, r7
	mov r8, #EMPTY_REGISTER
LOOP_CALLBACK_ARRAY:
	str r8, [r5], r6
	cmp r5, r7
	blt LOOP_CALLBACK_ARRAY

START_USER_PROGRAM:
	@ Muda para o modo usuário e muda o fluxo de execucao
	@ para o programa do usuario
	msr CPSR_c, #0x10
	ldr pc, =USER_PROGRAM

@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ INTERRUPCOES DE HARDWARE @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@

IRQ_HANDLER:
	stmfd sp!, {r0-r12, lr}

	@ Grava 1 em GPT_SR informando que o processador
	@ soube que houve interrupcao
	mov r9, #0x1
	ldr r10, =GPT_SR
	str r9, [r10]

CHECK_ALARMS:
	@ Vetor de alarmes
	ldr r9, =ALARMS_ARRAY

	@ Contador de tempo
	ldr r7, =CONTADOR
	ldr r7, [r7]

	@ Contador de loops
	mov r10, #0x0

	@ Valor do endereco da funcao no vetor
	ldr r8, [r9]

LOOP:
	@ Se a posicao estiver vazia verifica o proximo alarme
	cmp r8, #EMPTY_ALARM
	beq INCREMENT_LOOP

	@ Verifica todos os alarmes. Caso o tempo
	@ marcado no alarme seja igual o tempo do contador
	@ realiza uma acao
	ldr r2, [r9, #TIME_ALARM_OFFSET]
	cmp r7, r2
	bleq TRIGGER_ALARM

INCREMENT_LOOP:
	@ Carrega o proximo valor do vetor de alarmes
	ldr r8, [r9, #ALARMS_STRUCT_SIZE]!

	@ Incrementa contador de loops
	add r10, r10, #1

	@ Verifica se o loop ja varreu todo o vetor
	cmp r10, #MAX_ALARMS
	blt LOOP

	@ O vetor todo ja foi varrido. Todos alarmes foram
	@ tratados. Branch para dar continuidade ao fluxo.
	b INCREMENT_CONTADOR

TRIGGER_ALARM:
	@ Guarda valores nos registradores
	mrs r4, spsr
	stmfd sp!, {r0-r10, lr}

	@ Armazena em r5 o endereco da funcao
	ldr r5, [r9, #FUNCTION_ALARM_OFFSET]

	@ Marca alarme como atendido
	mov r6, #EMPTY_ALARM
	str r6, [r9, #FUNCTION_ALARM_OFFSET]

	@ Decrementa alarmes ativos
	ldr r2, =ACTIVE_ALARMS
	ldr r3, [r2]
	sub r3, r3, #1
	str r3, [r2]

	@ Muda para o modo USER
	msr CPSR_c, #0xD0

	@ Executa a funcao armazenada no vetor
	blx r5

	@ Volta para o modo IRQ
	mov r7, #SVC_SET_IRQ_MODE_CODE
	svc 0x0

	@ Restaura valores nos registradores
	ldmfd sp!, {r0-r10, lr}
	msr spsr, r4
	mov pc, lr

INCREMENT_CONTADOR:
	@ Incrementa o contador de tempo
	ldr r9, =CONTADOR
	ldr r10, [r9]
	add r10, r10, #1
	str r10, [r9]

CHECK_CALLBACK:
	@Verifica callbacks do sonar
	mov r9, #0 @callbacks testadas
	ldr r6, =CALLBACKS_ARRAY
VERIFICA_CALLBACK:
	cmp r9, #MAX_CALLBACKS
	bge FIM_VERIFICA_CALLBACKS
	
	@carrega id do sonar da callback
	@e verifica se a posicao esta vazia
	ldr r0, [r6, #ID_OFFSET]
	cmp r0, #EMPTY_REGISTER
	beq FIM_TRIGGER_CALLBACK

	@le sonar indicado em 'r0' e compara
	@com threshold, executa funcao se for menor
	mov r7, #SVC_READ_SONAR_CODE
	svc 0x0
	ldr r1, [r6, #DIST_THRESHOLD_OFFSET]
	cmp r0, r1
	bgt FIM_TRIGGER_CALLBACK
	
TRIGGER_CALLBACK:
	@ Marca callback como atendida
	@ Marca posicao do vetor como vazia
	mov r10, #EMPTY_REGISTER
	str r10, [r6]
	
	@ Decrementa callbacks ativas
	ldr r3, =CALLBACKS_ATIVAS
	ldr r10, [r3]
	sub r10, r10, #1
	str r10, [r3]
	
	@ Guarda valores dos registradores
	mrs r4, spsr
	stmfd sp!, {r0-r10, lr}

	@ Muda para o modo USER
	msr CPSR_c, #0xD0

	@ Executa a funcao armazenada no vetor
	ldr r2, [r6, #FUNCTION_ADDRESS_OFFSET]
	blx r2

	@ Volta para o modo IRQ
	mov r7, #SVC_SET_IRQ_MODE_CODE
	svc 0x0

	@ Restaura valores dos registradores
	ldmfd sp!, {r0-r10, lr}
	msr spsr, r4
FIM_TRIGGER_CALLBACK:

	add r6, r6, #CALLBACK_STRUCT_SIZE
	add r9, r9, #1
	b VERIFICA_CALLBACK
FIM_VERIFICA_CALLBACKS:

	ldmfd sp!, {r0-r12, lr}
	sub lr, lr, #0x4
	movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ INTERRUPCOES DE SOFTWARE @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@

SOFTWARE_INTERRUPTION:
	@ Trata a syscall que foi realizada
	msr CPSR_c, #0xD3
	
	cmp r7, #SVC_READ_SONAR_CODE
	beq READ_SONAR

	cmp r7, #SVC_REGISTER_PROXIMITY_CALLBACK_CODE
	beq REGISTER_PROXIMITY_CALLBACK

	cmp r7, #SVC_SET_MOTOR_SPEED_CODE
	beq SET_MOTOR_SPEED

	cmp r7, #SVC_SET_MOTORS_SPEED_CODE
	beq SET_MOTORS_SPEED

	cmp r7, #SVC_GET_TIME_CODE
	beq GET_TIME

	cmp r7, #SVC_SET_TIME_CODE
	beq SET_TIME

	cmp r7, #SVC_SET_ALARM_CODE
	beq SET_ALARM

	cmp r7, #SVC_SET_IRQ_MODE_CODE
	beq SVC_SET_IRQ_MODE
  
	movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ IMPLEMENTACAO DAS SYSCALLS @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ Retorna o contador de tempo do sistema em R0
GET_TIME:
	ldr r1, =CONTADOR
	ldr r0, [r1]
	movs pc, lr

@ Seta o contador de tempo do sistema
SET_TIME:
	ldr r1, =CONTADOR
	str r0, [r1]
	movs pc, lr

@ Le o sonar especificado  
@tem que ler o sonar
@r0 uns.int. id | r1 uns.shrt.* dist
READ_SONAR:
	stmfd sp!, {r4-r12}

	@testa se o id é valido
	cmp r0, #0
	blt RETORNA
	cmp r0, #15
	bgt RETORNA
	
	@limpa bits extras no id, guarda em r4, desloca para a posicao correta em DR
	ldr r4, =0b11111111111111111111111111110000
	bic r4, r0, r4
	mov r4, r4, lsl #2
	
	@MUX<id
	@GPIO_DR para r3
	ldr r2, =GPIO_DR
	ldr r3, [r2]
	
	@limpa bits a serem escritos no DR
	ldr r5, =0b00000000000000000000000000111100
	bic r5, r3, r5
	
	@escreve no DR (r5 tem DR com sonar_mux zerado)
	orr r3, r4, r5
	str r3, [r2]
	
	@tr=0
	@seta trigger para 0
	ldr r6, =0b00000000000000000000000000000010
	ldr r3, [r2]
	bic r3, r3, r6
	str r3, [r2]
	
	@15ms
	ldr r7, =ATRASO_15MS
	mov r8, #0
	ATRASA_15MS_1:
	add r8, r8, #1
	cmp r8, r7
	blt ATRASA_15MS_1
	
	@tr=1
	@seta trigger para 1
	ldr r6, =0b00000000000000000000000000000010
	ldr r3, [r2]
	orr r3, r3, r6
	str r3, [r2]

	@15ms
	ldr r7, =ATRASO_15MS
	mov r8, #0
	ATRASA_15MS_2:
	add r8, r8, #1
	cmp r8, r7
	blt ATRASA_15MS_2
	
	@tr=0
	@seta trigger para 0
	ldr r6, =0b00000000000000000000000000000010
	ldr r3, [r2]
	bic r3, r3, r6
	str r3, [r2]
	
	@flag==1 ? WAIT_FOR_FLAG : ESCREVE EM *X O SONAR:
	WAIT_FOR_FLAG:
	ldr r6, =0b11111111111111111111111111111110
	ldr r3, [r2]
	bic r3, r3, r6
	cmp r3, #0
	beq WAIT_FOR_FLAG
	
	@A escrita na variavel tem que ficar na BiCo
	@distancia < DATA do sonar
	ldr r6, =0b11111111111111000000000000111111
	ldr r2, =GPIO_PSR
	ldr r0, [r2]
	bic r0, r0, r6
	mov r0, r0, lsr #6

	ldmfd sp!, {r4-r12}
	movs pc, lr
	
RETORNA:
	ldmfd sp!, {r4-r12}
	mov r0, #-1
	movs pc, lr

@ Seta a velocidade do motor escolhido
SET_MOTOR_SPEED:
	stmfd sp!, {r4-r12}
	
	@ Verifica se a velocidade é valida
	cmp r1, #MAX_MOTOR_SPEED
	bgt INVALID_MOTOR_SPEED

	@ Verifica se o id é válido
	cmp r0, #0
	beq SET_MOTOR_0_SPEED
	cmp r0, #1
	beq SET_MOTOR_1_SPEED
	b INVALID_MOTOR_ID

	@ Seta a velocidade do motor 0
	SET_MOTOR_0_SPEED:
	@ Limpa os bits a serem escritos no DR (19-24)
	@ e o bit de write
	ldr r2, =GPIO_DR
	ldr r3, [r2]
	ldr r2, =MOTOR_0_MASK
	bic r3, r3, r2

	@ Desloca os bits da velocidade para a posicao correta
	lsl r1, r1, #19

	@ Coloca os bits da velocidade no DR que está
	@ sendo modificado
	orr r3, r3, r1

	@ Grava o DR modificado com a nova velocidade
	ldr r2, =GPIO_DR
	str r3, [r2]

	@ Retorna 0
	ldmfd sp!, {r4-r12}
	mov r0, #0
	movs pc, lr

	@ Seta a velocidade do motor 1
	SET_MOTOR_1_SPEED:
	@ Limpa os bits a serem escritos no DR (26-31)
	ldr r2, =GPIO_DR
	ldr r3, [r2]
	ldr r2, =MOTOR_1_MASK
	bic r3, r3, r2

	@ Desloca os bits da velocidade para a posicao correta
	lsl r1, r1, #26

	@ Coloca os bits da velocidade no DR que está
	@ sendo modificado
	orr r3, r3, r1

	@ Grava o DR modificado com a nova velocidade
	ldr r2, =GPIO_DR
	str r3, [r2]

	@ Retorna
	ldmfd sp!, {r4-r12}
	mov r0, #0
	movs pc, lr

	@ Quando o ID do motor for inválido
	INVALID_MOTOR_ID:
	@ Retorna -1
	ldmfd sp!, {r4-r12}
	mov r0, #-1
	movs pc, lr

	@ Quando a velocidade do motor for inválida
	INVALID_MOTOR_SPEED:
	@ Retorna -2
	ldmfd sp!, {r4-r12}
	mov r0, #-2
	movs pc, lr

SET_MOTORS_SPEED:
	stmfd sp!, {r4-r12}
	@ Verifica se as velocidades são validas
	cmp r0, #MAX_MOTOR_SPEED
	bgt invalid_motor_0_speed
	cmp r1, #MAX_MOTOR_SPEED
	bgt invalid_motor_1_speed

	@ Limpa os bits a serem escritos no DR (19-24)
	@ e o bit de write
	ldr r2, =GPIO_DR
	ldr r3, [r2]
	ldr r2, =MOTOR_0_AND_1_MASK
	bic r3, r3, r2

	@ Desloca os bits da velocidade
	@ do motor 0 para a posicao correta
	lsl r0, r0, #19

	@ Desloca os bits da velocidade
	@ do motor 1 para a posicao correta
	lsl r1, r1, #26

	@ Coloca os bits da velocidade no DR que está
	@ sendo modificado
	orr r3, r3, r0
	orr r3, r3, r1

	@ Grava o DR modificado com a nova velocidade
	ldr r2, =GPIO_DR
	str r3, [r2]

	@ Retorna 0
	ldmfd sp!, {r4-r12}
	mov r0, #0
	movs pc, lr

	@ Quando a velocidade do motor 0 for inválida
	invalid_motor_0_speed:
	ldmfd sp!, {r4-r12}
	mov r0, #-1
	movs pc, lr

	@ Quando a velocidade do motor 1 for inválida
	invalid_motor_1_speed:
	ldmfd sp!, {r4-r12}
	mov r0, #-2
	movs pc, lr

@ Adiciona um alarme ao sistema
@ Alarmes na memória são representados na memória
@ por um struct do tipo:
@ struct alarme {
@	*endereco;
@	tempo; 	
@ }
SET_ALARM:
	stmfd sp!, {r4-r12}
	@ Verifica se há espaco para mais um alarme
	ldr r3, =ACTIVE_ALARMS
	ldr r3, [r3]
	cmp r3, #MAX_ALARMS
	bge MAX_ALARMS_REACHED

	@ Verifica se o tempo é válido
	ldr r3, =CONTADOR
	ldr r3, [r3]
	cmp r1, r3
	blt INVALID_TIME

	@ Anda no vetor procurando uma posicao vazia
	ldr r3, =ALARMS_ARRAY
FIND_EMPTY_ALARM:
	ldr r2, [r3, #FUNCTION_ALARM_OFFSET]
	cmp r2, #EMPTY_ALARM
	beq POSITION_FOUND
	add r3, r3, #ALARMS_STRUCT_SIZE
	b FIND_EMPTY_ALARM

	POSITION_FOUND:
	@ Coloca o alarme no vetor de alarmes
	str r0, [r3, #FUNCTION_ALARM_OFFSET]
	str r1, [r3, #TIME_ALARM_OFFSET]

	@ Incrementa ACTIVE_ALARMS
	ldr r3, =ACTIVE_ALARMS
	ldr r4, [r3]
	add r4, r4, #1
	str r4, [r3]

	@ Retorna 0
	mov r0, #0
	movs pc, lr

	MAX_ALARMS_REACHED:
	ldmfd sp!, {r4-r12}
	mov r0, #-1
	movs pc, lr

	INVALID_TIME:
	ldmfd sp!, {r4-r12}
	mov r0, #-2
	movs pc, lr

REGISTER_PROXIMITY_CALLBACK:
	stmfd sp!, {r4-r12}
	
	@verifica id invalido
	cmp r0, #0
	blt RETORNA_ID_INVALIDO
	cmp r0, #15
	bgt RETORNA_ID_INVALIDO
	
	@verifica quantidade de callbacks ativos no sistema
	ldr r7, =CALLBACKS_ATIVAS
	ldr r3, [r7]
	cmp r3, #MAX_CALLBACKS
	bge RETORNA_MAX_CALLBACKS
	
	@registra a callback
	@incrementa numero de callbacks ativas
	add r3, r3, #1
	str r3, [r7]
	
	@encontra a primeira posicao livre no vetor de callbacks
	ldr r5, =CALLBACKS_ARRAY
	ldr r6, =CALLBACK_STRUCT_SIZE
FIND_EMPTY_POSITION:
	ldr r4, [r5, #ID_OFFSET]
	mov r10, r5
	add r5, r5, r6
	cmp r4, #EMPTY_REGISTER
	bne FIND_EMPTY_POSITION
	
	@aponta para o primeiro valor vazio da array
	@armazena o registro
	str r0, [r10, #ID_OFFSET]
	str r1, [r10, #DIST_THRESHOLD_OFFSET]
	str r2, [r10, #FUNCTION_ADDRESS_OFFSET]
	
	ldmfd sp!, {r4-r12}
	mov r0, #0
	movs pc, lr

RETORNA_MAX_CALLBACKS:
	ldmfd sp!, {r4-r12}
	mov r0, #-1
	movs pc, lr

RETORNA_ID_INVALIDO:
	ldmfd sp!, {r4-r12}
	mov r0, #-2
	movs pc, lr

SVC_SET_IRQ_MODE:
	@ Seta o modo do processador para IRQ
	mov r0, lr
	msr CPSR_c, #0xD2
	mov lr, r0
	mov pc, lr

@@@@@@@@@@@@@@
@ SECAO DATA @
@@@@@@@@@@@@@@

.data
	CONTADOR: .word 0x0

	CALLBACKS_ATIVAS: .word 0x0

	CALLBACKS_ARRAY: .space 0x60 @ numero maximo de callbacks * tamanho de cada registro

	ACTIVE_ALARMS: .word 0x0

	ALARMS_ARRAY:  .zero 64 @ Como MAX_ALARMS = 8
							@ são necessários 64 bytes
