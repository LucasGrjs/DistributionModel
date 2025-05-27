/**
* Name: continuous_move
* Description: A 3D model which show how to represent an evacuation system with 
* 	obstacles, cohesion factor and velocity. The people are placed randomly and have 
* 	to escape by going to a target point
* Tags: shapefile, gis, agent_movement, skill
*/

model continuous_move 

global 
{ 
	//Shapefile of the buildings
	file building_shapefile <- file("includes/alameda/buildings3.shp");
	shape_file targets_shape_file <- shape_file("includes/alameda/targets.shp");
	shape_file start_area <- shape_file("includes/alameda/start_area.shp");
	//Shape of the environment
	geometry shape <- envelope(building_shapefile);
	int maximal_turn <- 90; //in degree
	int cohesion_factor <- 10;
	//Size of the people
	float people_size <- 1.0;
	//Space without buildings
	geometry free_space;
	geometry start_area_shape <- first(start_area.contents);
	//Number of people agent
	int nb_people <- 5000;
	//Point to evacuate
	list<point> target_point <- list({shape.width, 0}, {0,shape.height});//, {0,0}, {shape.width, shape.height});
	
	init { 
		free_space <- copy(shape);
		//Creation of the buildinds
		create building from: building_shapefile {
			//Creation of the free space by removing the shape of the different buildings existing
			free_space <- free_space - (shape + people_size);
		}
		create target from: targets_shape_file {
			free_space <- free_space - (shape + people_size);
			if(index > 3)
			{
				open <- false;
			}
		}	
		//write("target " + list(target));
		//Simplification of the free_space to remove sharp edges
		free_space <- free_space simplification(1.0);
		//Creation of the people agents
		create people number: nb_people {
			//People agents are placed randomly among the free space
			location <- (any_location_in(start_area_shape)) with_precision 2;
			target_loc <-  ((target where each.open) closest_to self).index;
		} 	
	}
	
	reflex
	{
		write("Thematic Model CYCLE ---------" + cycle + "---------");
		if(length(people where !dead(each)) = 0){
 			write("total_duration model " + float(total_duration)/1000 + "s");
 			//do die;
		}
	}
}

//Species which represent the exit 
species target {
	bool open <- true;
	aspect default {
		if(open)
		{		
			draw shape color: #red border: #black;
			draw " " + index at: ({location.x, location.y} /*- {0,25}*/) font: font('Default', 25, #bold) color: #black;
		}else
		{
			draw shape color: #black border: #black;
			draw " " + index at: ({location.x, location.y} /*- {0,25}*/) font: font('Default', 25, #bold) color: #black;
		}
	}
}

//Species which represent the building 
species building {
	//Height of the buildings
	float height <- 3.0 + rnd(5);
	aspect default {
		draw shape color: #gray depth: height;
	}
}

//Species people which move to the evacuation point using the skill moving
species people skills:[moving]{
	
	//Target point to evacuate
	int target_loc;
	//Speed of the agent
	float speed <- 0.5 + rnd(1000) / 1000;
	//Velocity of the agent
	point velocity <- {0,0};
	//Direction of the agent taking in consideration the maximal turn an agent is able to make
	float heading max: heading + maximal_turn min: heading - maximal_turn;
	
	//Size of the agent
	float size <- people_size; 
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
		
	//Reflex to kill the agent when it has evacuated the area
	reflex end when: self distance_to target[target_loc] <= size*2
	{
		//write name + " is arrived";
		do die;
	}
	
	//Reflex to compute the velocity of the agent considering the cohesion factor
	reflex follow_goal  {
		velocity <- (velocity + ((target[target_loc].location - location) / cohesion_factor)) with_precision 2;
	}
	
	//Reflex to apply separation when people are too close from each other
	reflex separation {
		point acc <- {0,0};
		ask (people at_distance size)  {
			acc <- acc - (location - myself.location);
		}  
		velocity <- (velocity + acc) with_precision 2;
	}
	
	//Reflex to avoid the different obstacles
	reflex avoid { 
		point acc <- {0,0};
		list<building> nearby_obstacles <- (building at_distance people_size);
		loop obs over: nearby_obstacles {
			acc <- acc - (obs.location - location); 
		}
		velocity <- (velocity + acc) with_precision 2; 
	}
	
	//Reflex to move the agent considering its location, target and velocity
	reflex move {
		point old_location <- copy(location);
		do goto target: location + velocity ;
		if not(self overlaps free_space ) {
			location <- (((location closest_points_with free_space)[1])) with_precision 2;
		}
		velocity <- (location - old_location) with_precision 2;
	}	
	
	aspect default {
		draw circle(1) at: location color: color;	
	}
}
experiment display_people
{
	reflex snapshot{
		write("SNAPPING___________________________________ " + cycle);
		ask simulation{			
			save (snapshot("map")) to: "../output.log/snapshot/central/people_" + cycle + ".png" rewrite: true;			
		}
	}
	output {
		display map{
			species building refresh: false;
			species target refresh: false;
			species people;
		}
	}
}
experiment main{
	
}

