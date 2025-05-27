/**
* Name: Distribution_model
* Distribution model to distribute a thematic model using a grid. 
* Author: Lucas Grosjean
* Tags: Visualisation, HPC, distributed ABM, distribution model
*/

model Distribution

import "../ThematicModel/Continuous_Move.gaml" as Thematic

global{
	int end_cycle <- 250;
	int MPI_RANK;
	int MPI_SIZE;
	
	int grid_width <- 2;
	int grid_height <- 2;
	
	int nb_people <- 10000;
	
	file building_shapefile <- file("../ThematicModel/includes/alameda/buildings3.shp"); //Shape of the environment
	geometry shape <- envelope(building_shapefile); 
	
	init{	
 		/* INIT THEMATIC MODEL */
 		create Thematic.main with:[seed::seed, nb_people::nb_people]; // create the evacuation model with parameters
 		write("Thematic.main");
 		
 		/* INIT COMMUNICATION AGENT */
 		create Communication_Agent_MPI;
 		
 		/* INIT MPI NETWORK*/
 		MPI_RANK <- Communication_Agent_MPI[0].MPI_RANK;
 		MPI_SIZE <- Communication_Agent_MPI[0].MPI_SIZE;
		
 		/* INIT PARTITIONNING AGENT */
 		create Partitionning_agent;
 		write("Partitionning_agent");
 		
 		/* INITIAL PEOPLE IN THE THEMATIC SIMULATION */	
		list<people> init_peoples;
 		ask Thematic.main[0].simulation{
 			init_peoples <- list(people); // get the initial population of people
 		}
 		
 		/* REMOVE PEOPLE NOT IN MY CELL */
		loop current_people over: init_peoples{
 			cell c <- cell(current_people.location);
			if(c.rank != MPI_RANK) {
				ask current_people{
					do die;	
				}
			}
 		}
 		write("end init");
 	}
 	
 	// execute a step of the Evacuation Model
 	action _step_sub_model{	
		ask Thematic.main[0].simulation{
			do _step_;
		}
	}
	
	reflex{
		write("CYCLE -------[" + cycle + "]-------");
		do _step_sub_model;
		if(cycle = end_cycle){
			write("-----------------end_cycle reached-----------------");
			write("DISTRIBUTION MODEL IS OVER");
 			write("total_duration " + float(total_duration)/1000 + "s");
 			
 			ask Thematic.main[0].simulation{
 				do die;
 			}
	 		do die;
		}
	}
}
// Partitionning Agent managing a cell of the grid
species Partitionning_agent{
	reflex update{	
		list<people> peoples;
		map<int,list<people>> people_to_send;
		
		ask Thematic.main[0]{
			peoples <- people collect each where not dead(each);
		}
		loop current_people over: peoples{			
			if(not dead(current_people)){	
				cell c <- cell(current_people.location); // get cell where the agent is currently on
				if(c.rank != MPI_RANK){
					if( people_to_send[c.rank] = nil){
						people_to_send[c.rank] <- list<people>(current_people); // update people_to_send
					}else{
						people_to_send[c.rank] << current_people;
					}
				}
			}	
		}
		do send_people_not_in_my_cell(people_to_send);
	}
	
	// sending people not in my cell agent away
	action send_people_not_in_my_cell(map<int,list<people>> people_to_send){
		map<int,list<people>> new_people;
		ask Communication_Agent_MPI{			
			 new_people <- MPI_ALLTOALL(people_to_send);
			 write("agent received : " + new_people);
		}
		loop peoples over: people_to_send{
			ask peoples{
				do die; // remove the migrated agent from our distribution model
			}
		}
	}
}

// GRID Agent
grid cell width: grid_width height: grid_height neighbors: 4{ 
	int rank <- grid_x + (grid_y * grid_width);
	
	aspect default{
		draw self.shape color: rgb(#white,125) border:#black;	
		draw "[" + self.grid_x + "," + self.grid_y +"] : " + rank color: #red font:font('Default', 15, #bold) at: {self.location.x, self.location.y};
	}
}

species Communication_Agent_MPI skills:[MPI_SKILL]{}

experiment distribution_experiment type: MPI_EXP{
	reflex snapshot{
		write("SNAPPING___________________________________ " + cycle);
		int mpi_id <- MPI_RANK;
		ask simulation{	
			if(true){			
				save (snapshot("people")) to: "../output.log/snapshot/GRID/GRID" + mpi_id + "/people_" + cycle + ".png" rewrite: true;		
			}		
		}
	}
	output {
		display people{
			graphics "exit" {
				ask Thematic.main[0].simulation{
					loop people_agent over: people{				
						draw circle(1) at: people_agent.location color: people_agent.color border:#black;	
					}
					loop building_agent over: building{
						draw building_agent color: #gray depth: building_agent.height border: #black;
					}
					loop target_agent over: target{
						if(target_agent.open)
						{	
							draw target_agent color: #red border: #black;						
						}else
						{
							draw target_agent color: #black border: #black;
						}
					}
				}
			}
			species cell;
		}
		
	}
}
