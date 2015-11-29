#include "api_robot2.h"

#define MAX_TURNS         50
#define THRESHOLD		  1500
#define FORWARD_SPEED	  20
#define TURN_SPEED   	  10

void ronda();
void avoidWall();
void turnRight();
void setAlarm();
void busy_wait(int j);

int contadorVoltas = 1;

void _start() {
	ronda();
	while(1) {
	}
}

/* Se reto e cria alarmes que de tempos em tempos faz o robo
/* virar à direita em aproximadamente 90 graus */
void ronda() {
	/* Cria um callback que faz com que o robo evite a parede quando
	/* o sensor 3 estiver muito perto de uma parede chamando avoidWall() */
	register_proximity_callback(3, THRESHOLD, &avoidWall);
	/* Reinicia o contador do SOUL */
	set_time(0);
	/* Antes de andar evita uma possível parede */
	avoidWall();
	/* Anda para frente */
	set_motors_speed(FORWARD_SPEED, FORWARD_SPEED);
	/* Adiciona um alarme para fazer o robo virar depois de determinado tempo */
	setAlarm();
}

/* Desvia de uma parede à frente girando para a direita */
void avoidWall() {
	short dist3;
	read_sonar(3, &dist3);
	while(dist3 < THRESHOLD ) {
		set_motors_speed(0, TURN_SPEED);
		read_sonar(3, &dist3);
	}
	set_motors_speed(FORWARD_SPEED, FORWARD_SPEED);
}

/* Vira à direita até se afastar se uma parede à frente */
void turnRight() {
	set_motors_speed(0, 10);
	busy_wait(690000);
	contadorVoltas++;
	if(contadorVoltas > MAX_TURNS)
		contadorVoltas = 1;
	ronda();
}

/* Adiciona um alarme que faz com que o robo realize uma curva depois de
/* um tempo igual a contadorVoltas */
void setAlarm(){
	add_alarm(&turnRight, contadorVoltas);
}

/* Delay burro */
void busy_wait(int j) {
	int i;
	for(i=0; i < j; i++) {
		i = i*2;
		i = i/2;
	}
}