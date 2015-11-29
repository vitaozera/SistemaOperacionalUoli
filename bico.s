.text
.global set_motor_speed
.global set_motors_speed
.global read_sonar
.global read_sonars
.global register_proximity_callback
.global add_alarm
.global get_time
.global set_time

.align 4

@ Número de cada syscall
.set SVC_READ_SONAR_CODE,                  16
.set SVC_REGISTER_PROXIMITY_CALLBACK_CODE, 17
.set SVC_SET_MOTOR_SPEED_CODE,             18
.set SVC_SET_MOTORS_SPEED_CODE,            19
.set SVC_GET_TIME_CODE,                    20
.set SVC_SET_TIME_CODE,                    21
.set SVC_SET_ALARM_CODE,                   22

.align 4

/* Funções da API de controle "api_robot2.h" */

read_sonars:
	stmfd sp!, {r4-r12, lr}
	mov r4, #0
	mov r5, r0
	
KEEP_READING:
	mov r0, r4
	mov r7, #SVC_READ_SONAR_CODE
	svc 0x0
	str r0, [r5], #4
	add r4, r4, #1
	cmp r4, #15
	ble KEEP_READING
	ldmfd sp!, {r4-r12, pc}

register_proximity_callback:
	stmfd sp!, {r4-r12, lr}
	mov r7, #SVC_REGISTER_PROXIMITY_CALLBACK_CODE
	svc 0x0
	ldmfd sp!, {r4-r12, pc}

set_motor_speed:
	stmfd sp!, {r7, lr}
	mov r7, #SVC_SET_MOTOR_SPEED_CODE
	svc 0x0
	ldmfd sp!, {r7, pc}

set_motors_speed:
	stmfd sp!, {r7, lr}
	mov r7, #SVC_SET_MOTORS_SPEED_CODE
	svc 0x0
	ldmfd sp!, {r7, pc}

read_sonar:
	stmfd sp!, {r4-r12, lr}
	mov r7, #SVC_READ_SONAR_CODE
	svc 0x0
	strh r0, [r1]
	ldmfd sp!, {r4-r12, pc}

get_time:
	stmfd sp!, {r7, lr}
	mov r7, #SVC_GET_TIME_CODE
	svc 0x0
	ldmfd sp!, {r7, pc}

set_time:
	stmfd sp!, {r7, lr}
	mov r7, #SVC_SET_TIME_CODE
	svc 0x0
	ldmfd sp!, {r7, pc}
	
add_alarm:
	stmfd sp!, {r4-r12, lr}
	mov r7, #SVC_SET_ALARM_CODE
	svc 0x0
	ldmfd sp!, {r4-r12, pc}