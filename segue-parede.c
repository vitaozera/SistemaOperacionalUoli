#include "api_robot2.h"

#define FIND_MODE         0
#define SET_POSITION_MODE 1
#define FOLLOW_MODE       2
#define THRESHOLD		  1200
#define ACCEPTABLE_ERROR  100
#define ACCEPTABLE_DIFFERENCE 300

int find_wall();
int set_position_to_left();
void follow_wall();
void busy_wait(int j);

int mode = FIND_MODE;

void _start() {

	while(1) {
		switch(mode) {
			case(FIND_MODE):
				/* Anda em linha reta até encontrar parede */
				set_motors_speed(10, 10);
				if(find_wall() == 1) {
					/* Encontrou uma parede, muda o modo
					 e pára o robo*/
					mode = SET_POSITION_MODE;
					set_motors_speed(0, 0);
				}
				break;
			case(SET_POSITION_MODE):
				/* Encontrou uma parede, posicione o lado esquerdo ao lado dela */
				/* e mude o modo */
				if(set_position_to_left() == 1) {
					mode = FOLLOW_MODE;
				}
				break;
			case(FOLLOW_MODE):
				/* Siga a parede que foi encontrada */
				follow_wall();
				break;
		}
	}
}

/* Anda em linha reta até encontrar uma parede */
int find_wall() {
	short dist3, dist4;

	/* Verifica as distancias dos sonares às paredes */
	read_sonar(3, &dist3);
	read_sonar(4, &dist4);

	/* Se a distância do s3 ou s4 for menor que o limiar, encontrou parede */
	if(dist3 > THRESHOLD && dist4 > THRESHOLD)
		return 0;
	else
		return 1;
}

/* Posiciona a lateral esquerda do robô paralelamente à parede */
int set_position_to_left() {
	short dist0, dist14;
	/* Roda o robo até encontrar uma parede à esquerda */
	set_motors_speed(0, 10);

	/* Se a distância do sonar da esquerda foi menor que o limiar + erro */
	/* é porque encontrou uma parede. */
	read_sonar(0, &dist0);
	read_sonar(14, &dist14);
	if(dist0 < THRESHOLD + ACCEPTABLE_ERROR && dist14 < THRESHOLD + ACCEPTABLE_ERROR) {

		/* O robo está lado a lado com a parede.
		/* Pare-o */
		set_motors_speed(0, 0);
		return 1;
	}
	/* Não conseguiu encontrar parede */
	return 0;
}

/* Segue lateralmente a parede */
void follow_wall() {
	short dist1, dist14, dist3, dist4;

	/* Se o sonar 1 estiver lendo uma distância muito alta vira à esquerda */
	read_sonar(1, &dist1);
	if(dist1 > THRESHOLD ) {
		set_motors_speed(10, 2);
		busy_wait(300000);
		set_motors_speed(0, 0);
	}
	/* Se o sonar 1 estiver lendo uma distância muito baixa vira à direita */
	else if(dist1 < THRESHOLD - ACCEPTABLE_DIFFERENCE) {
		set_motors_speed(2, 10);
		busy_wait(300000);
		set_motors_speed(0, 0);
	}
	/* Está a uma boa distância da parede */
	else {
		set_motors_speed(10, 10);
		busy_wait(300000);
	}
	/* Se houver uma parede à frente rodar até evitar a parede */
	read_sonar(3, &dist3);
	while(dist3 < THRESHOLD) {
		set_motors_speed(0, 10);
		busy_wait(1000);
		set_motors_speed(0, 0);
		read_sonar(3, &dist3);
	}
}

/* Delay burro */
void busy_wait(int j) {
	int i;

	for(i = 0; i < j; i++) {
		i = i * 2;
		i = i / 2;
	}
}