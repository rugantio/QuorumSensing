/**
* Name: QuorumSensing
* Author: Costantino Carugno, Federico di Credico, Francesco Puccioni
* Description: This model implements a prototype of Quorum Sensing, as observed in Aliivibrio fischeri.
* Il modello simula il quorum sensing, un meccanismo che molti organismi unicellulari utilizzano per essere sensibili
* alla densità con la quale popolano un ambiente. Se le cellule sono molto dense si illuminano (cambiano colore da
* nero a rosso), altrimenti si spengono. Le cellule diffondono nell'ambiente un ormone che può essere assorbito da 
* tutte le altre cellule. La frequenza con la quale emettono l'ormone è direttamente proporzionale a quella con la
* quale assorbono
* Tags: Tag1, Tag2, TagN
*/

model QuorumSensing

global {
	/* Global variables */
	int world_dimension <- 300 parameter:"World Dimension" min:20 max:1000 category:"Global";
	int ncell <- 200 parameter:"Number of Cells" min:25 max:3000 category:"Global";
	int cluster_dim <- 30 parameter:"Dimension of the cluster" min:5 max:100 category:"Global";
	float alpha <- 4/5 parameter:"Spreading factor" min:0.1 max:5.0 category:"Global";
	
	/* Cells attributes */
	int ray_of_perception <- 30 parameter:"Food sensing horizon" min:5 max: 100 category:"Cell";
	int increase_of_health <- 40 parameter:"Health gained eating food" min:10 max:100 category:"Cell";
	float lightning_threshold <- 0.05 parameter:"Bioluminescence threshold" min:0.01 max: 0.1 category:"Cell";
	
	/* Food attributes */
	int food_cluster <- 20 parameter:"Food generated in the cluster" min:5 max:100 category:"Food";
	int food_rnd <- 5 parameter:"Food generated randomly" min:1 max:30 category:"Food";
	
	geometry shape <- square(world_dimension);
	
	init {
		create cell number: ncell with: (location: any_location_in(shape));//initial cells are created randomly in our space
	}
	
	reflex generate_food when: cycle mod 1 = 0 {
		create food number: food_cluster with: (location: any_location_in(circle(cluster_dim)));//clustering is hardcoded for now, can be switched to an emergent property later
		create food number: food_rnd;
	}
}

species cell skills: [moving] {
	/* Other cell attributes, hardcoded */
	float spreading_speed;
	int aging_speed;
	int dimension;
	float absorbing_frequency;
	rgb my_color;
	int max_health;
	int health;
	int wandering_amplitude;
	list<int> memory <- [];

	init {
		spreading_speed <- 1.5;
		aging_speed <- 1;
		dimension <- 4;
		absorbing_frequency <- 0.0;
		my_color <- #black;
		max_health <- 1000;
		health <- max_health;
		wandering_amplitude <- 10;
	}
	
	reflex move_to_food when: !empty(food at_distance ray_of_perception) {   //cells go after species food if detected                                         
		list<food> targets <- food at_distance ray_of_perception;
		do goto(targets with_min_of (distance_to(each,self)));
	}
	
	reflex move when: empty(food at_distance ray_of_perception) { //if food is not available cells just wander around
		do wander amplitude: wandering_amplitude;
	}
	
	reflex eat when: !empty(food at_distance dimension) {//cells gain health eating food
		ask one_of(food at_distance dimension) {
			do die;
		}
		health <- health + increase_of_health;
		if health > max_health {
			health <- max_health;
		}
	}
	
	reflex inglobe_hormone when: !empty(hormone at_distance dimension) {//hormons are also inglobed, if found
		ask one_of(hormone at_distance dimension) {
			do die;
		}
		add cycle to: memory;//number of cycle is added to a "memory" list, this is used later to calculate the frequency
		if length(memory) > 11 {//memory is of fixed length
			remove from: memory index: 0;
		}
	}
	
	reflex basic_memory when: flip(0.01) {
		add cycle to: memory;
		if length(memory) > 1 {
			if memory[length(memory)-2] = memory[length(memory)-1] {
				remove from: memory index: length(memory) - 1;
			}
		}
		if length(memory) > 11 {
			remove from: memory index: 0;
		}
	}
	
	
	reflex get_old { //cells age each cycle
		health <- health - 1;
		if health <= 0 {
			do die;
		}
	}
	
	reflex calculate_frequency { //this reflex calculates the frequency absorption of the hormons 
		if length(memory) = 11 {
			list<int> periods <- [];
			loop i from:1 to: length(memory)-1 {
				add item: memory[i]-memory[i-1] to: periods;
			}
			absorbing_frequency <- 1/mean(periods);
		}
	}
	
	reflex spread_hormone when: flip(absorbing_frequency*alpha){ //the hormones are spread randomly in space, with a spreading frequency that is a multiple of the absorbing frequency
		int random_direction <- rnd(360);
		create hormone with: [location::{location.x + dimension*cos(random_direction),location.y + dimension*sin(random_direction)}, heading:: random_direction, speed:: spreading_speed];
	}
	
	reflex switch_on when: absorbing_frequency > lightning_threshold {//if the absorbing frequency is high enough, cells begin to bioluminescence (switch color to red)
		my_color <- #cyan;
	}

	reflex switch_off when: absorbing_frequency <= lightning_threshold {//if the absorbing frequency is NOT high enough, cells stop to bioluminescence (switch color to black)
		my_color <- #black;
	}
	
	aspect base {
		draw circle(dimension) color: my_color;
	}

}

species food skills: [moving]{//we use the food agent to aggregate cells; it's very basic, they are spawned and only diffused in space
	reflex diffuse {
		do wander;
	}
	
	aspect base {
		draw circle(1) color: #green;
	}
	
	reflex out_of_board when: location.x <= 1 or location.x >= world_dimension-1 or location.y <= 1 or location.y >= world_dimension - 1{
		do die;
	}
	
}

species hormone skills: [moving]{
	int age <- 50;
	reflex get_old {//like cells, hormons age as well
		age <- age - 1;
		if age <= 0 {
			do die;
		}
	}
	
	reflex diffuse {//diffusion is not simple wandering, the speed is progressively diminished, simulating a sort of friction
		if speed > 1 {
			do move;
			speed <- speed - 0.05;
		}
		else {
			speed <- 0.95;
			do wander;
		}
	}
	
	reflex out_of_board when: location.x <= 1 or location.x >= world_dimension - 1 or location.y <= 1 or location.y >= world_dimension - 1{
		do die;
	}
	
	aspect base {
		draw circle(0.7) color: #red;
	}
	
}

experiment quorum_sensing type:gui {
	output {
		display "Cell Population" type: java2D{
			chart "Cell Population" type: series background: #black color: #lightgreen axes: #lightgreen   size: {0.5,0.5} position: {0, 0}
			title_font_size: 32.0 title_font_style:'italic' tick_font: 'Monospaced' tick_font_size:14 tick_font_style:'bold' x_serie_labels:cycle x_label:'Time' y_label:'Cell number'{
				data "Regular cells" value: (list(cell) count (each.my_color=#black)) accumulate_values:true color:#white style:line marker_shape:marker_empty;
				data "Bioluminescent cells" value: (list(cell) count (each.my_color=#cyan)) accumulate_values:true color:#red style:line marker_shape:marker_empty;
		//		data "Classic" value: [cycle + 1, cycle] marker_shape: marker_circle color: # yellow;	
			}
			chart "Cell Cluster" type: series background: #black color: #lightgreen axes: #lightgreen  size: {0.5,0.5} position: {0.5, 0}
			title_font_size: 32.0 title_font_style:'italic' tick_font: 'Monospaced' tick_font_size:14 tick_font_style:'bold' x_serie_labels:cycle x_label:'Time' y_label:'Cell number'{
				data "Bioluminescent cells in the cluster" value: (list(cell) count (each.my_color=#cyan and (agents_inside(circle(cluster_dim))))) accumulate_values:true color:#red style:line marker_shape:marker_empty;
			}
		}
		display Experiment {
			species hormone aspect: base;
			species cell aspect: base;
			species food aspect: base;
		}
	}
}

