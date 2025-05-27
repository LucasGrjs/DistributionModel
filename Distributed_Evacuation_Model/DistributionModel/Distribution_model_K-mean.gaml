/**
* Name: Kmean
* Based on the internal empty template. 
* Author: lucas
* Tags: 
*/

model Kmean

import "../ThematicModel/Continuous_Move.gaml" as continuous_move

global
{
	file building_shapefile <- file("../ThematicModel/includes/alameda/buildings3.shp");
	geometry shape <- envelope(building_shapefile);
	
	list<people> all_people_in_sub_model;
	list<target> targets;
	int MPI_RANK;								// MPI RANK of the current  model instance
	int MPI_SIZE;								// number of MPI rank on the network
	
	int nb_people <- 1000;						// number of people in the Model
	int end_cycle <- 250;
	
	init
	{
		seed <- 70.0;
		
 		create Communication_Agent_MPI; 					// init of the communication agent
 		MPI_RANK <- Communication_Agent_MPI[0].MPI_RANK;	// get the MPI Rank of this instance
 		MPI_SIZE <- Communication_Agent_MPI[0].MPI_SIZE;	// get the size of the MPI Network
 		
 		write("MPI_RANK " + MPI_RANK);
 		write("MPI_SIZE " + MPI_SIZE);
 		
		create continuous_move.main with:[seed::seed, nb_people::nb_people];
		ask(continuous_move.main[0])
		{
			all_people_in_sub_model <- list(people);
			targets <- list(target);
		}
		
		create centroid_agent number: MPI_SIZE
		{
			if(MPI_RANK < 9)
			{
				location <- targets[index].location;			
			}else
			{				
				location <- one_of(all_people_in_sub_model).location;
			}
		}
		
		loop agt over: all_people_in_sub_model
		{
			centroid_agent closest_centroid <- centroid_agent closest_to agt;
			ask closest_centroid
			{				
				write("adding " + agt + " to " + closest_centroid);
				add agt to: my_points;
			}
		}
		
		ask centroid_agent
		{	
			write("my_points " + my_points);
			my_points <- my_points where !dead(each);
			location <- mean(my_points collect each.location); // move centroid in the middle of the convex
			convex <- convex_hull(polygon(my_points));
			
			if(index != MPI_RANK)
			{
				ask my_points
				{
					do die;
				}
			}
		}
	}
 	
	action _step_sub_model
	{	
		ask continuous_move.main[0].simulation
		{
			do _step_;
			
			all_people_in_sub_model <- list(people);
		}
	}
	
	reflex
	{
		write("CYCLE -------[" + cycle + "]-------");
		do _step_sub_model;
		bool model_is_over;

		if(cycle = end_cycle)
		{
			model_is_over <- true;
		}
		if(model_is_over)
		{
			write("DISTRIBUTION MODEL IS OVER");
 			write("total_duration " + float(total_duration)/1000 + "s");
 			
 			ask continuous_move.main[0].simulation
 			{
 				do die;
 			}
	 		do die;
		}else
		{
			if(cycle mod 5 = 0)
			{
				ask centroid_agent[MPI_RANK]
				{
					do update_custom;
					do update_centroid_location;
				}
			}	
		}
	}
}

species centroid_agent
{
	rgb color_kmean <- rgb(rnd(255),rnd(255),rnd(255));
	list<people> my_points;
	geometry convex;
	
	list<unknown> write_people(people pe)
	{
		//write("writing pe " + pe);
		//write("writing pe.location " + pe.location);
		//write("writing pe.location 2 " + pe.location with_precision 2);
		//write("writing pe.target_loc " + pe.target_loc);
		//write("writing pe.speed " + pe.speed);
		//write("writing pe.speed 2 " + pe.speed with_precision 2);
		////write("writing pe.velocity " + pe.velocity);
		//write("writing pe.velocity 2 " + pe.velocity with_precision 2);
		//write("writing pe.heading " + pe.heading);
		//write("writing pe.heading 2 " + pe.heading with_precision 2);
		list<unknown> pe_attributes <- [pe.location with_precision 2, pe.target_loc, pe.speed with_precision 2, pe.velocity with_precision 2, pe.heading with_precision 2];
		//write("pe_attributes " + pe_attributes);
		return pe_attributes;
	}
	people create_people(list<unknown> value)
	{
		point location_people <- point(value[0]);
		int target_loc_people <- int(value[1]);
		float speed_people <- float(value[2]);
		point velocity_people <- point(value[3]);
		float heading_people <- float(value[4]);
		
		/*write("location_people " + location_people);
		write("target_loc_people " + target_loc_people);
		write("speed_people " + speed_people);
		write("velocity_people " + velocity_people);
		write("heading_people " + heading_people);*/
		people new_people;
		ask(continuous_move.main[0])
		{
			create people with: 
				[	location::location_people,
					target_loc::target_loc_people,
					speed::speed_people,
					velocity::velocity_people,
					heading::heading_people
				];
				new_people <- people[length(people)-1];
				//write("new_people pe " + new_people);
				//write("new_people pe.location " + new_people.location);
				//write("new_people pe.target_loc " + new_people.target_loc);
				//write("new_people pe.speed " + new_people.speed);
				//write("new_people pe.velocity " + new_people.velocity);
				//write("new_people pe.heading " + new_people.heading);
		}
		return new_people;
	}
	
	action update_custom
	{
		map<int, list<people>> migrating_agents;
		map<int, list<list<unknown>>> migrating_people;
		loop tmp over: my_points
		{
			if(!dead(tmp))
			{	
				centroid_agent closest <- centroid_agent closest_to tmp;
				if(closest != self)
				{
					//write("tmp leaving " + tmp);
					if(migrating_agents[closest.index] = nil)
					{
						migrating_agents[closest.index] <- list<people>(tmp);
					}else
					{
						migrating_agents[closest.index] << tmp;
					}
				}
			}
		}
		
		loop migrating_agent over: migrating_agents.pairs
		{
			//write("migrating_agent " + migrating_agent);
			//write("migrating_agent.key " + migrating_agent.key);
			//write("migrating_agent.value " + migrating_agent.value);
			
			loop migrating_agent_to_remove over: migrating_agent.value
			{
				if(migrating_people[migrating_agent.key] = nil)
				{
					list<unknown> migrating_people_attribute <- write_people(migrating_agent_to_remove);
					migrating_people[migrating_agent.key] <- list([migrating_people_attribute]);
					//write("migrating_people[migrating_agent.key] " + migrating_people[migrating_agent.key]);
				}else
				{
					migrating_people[migrating_agent.key] << write_people(migrating_agent_to_remove);
					//write("migrating_people[migrating_agent.key] post " + migrating_people[migrating_agent.key]);
				}
			}
		}
		//write("final migrating_people " + migrating_people);
		
		ask Communication_Agent_MPI
		{
			//write("migrating_people before comm " + migrating_people);
			map<int, list<unknown>> received_peoples <- MPI_ALLTOALL(migrating_people);
			//write("received_people from comm " + received_peoples);
			
			loop received_peoples_list over: received_peoples.pairs
			{	
				//write("received_peoples_list " + received_peoples_list);
				//write("received_peoples_list lenght " + length(received_peoples_list.value));
				
				loop value over: received_peoples_list.value
				{
					//write("value " + value);
					people new_people <- myself.create_people(list<unknown>(value));
					add new_people to:myself.my_points;
				}
			}
		}
		
		
		loop migrating_agent over: migrating_agents.pairs
		{
			loop migrating_agent_to_remove over: migrating_agent.value
			{
				remove migrating_agent_to_remove from: my_points; // remove from my point
			}
			loop migrating_agent_to_remove over: migrating_agent.value
			{
				//write("killing " + migrating_agent_to_remove);
				ask migrating_agent_to_remove
				{					
					do die; // kill this agent
				}
			}
		}
		
		write("lenght["+self+"] : " + length(my_points));
		my_points <- my_points where !dead(each);
		location <- mean(my_points collect each.location); // move centroid in the middle of the convex
		convex <- convex_hull(polygon(my_points));
	}
	
	action update
	{
		map<int, list<people>> migrating_agents;
		loop tmp over: my_points
		{
			if(!dead(tmp))
			{	
				centroid_agent closest <- centroid_agent closest_to tmp;
				if(closest != self)
				{
					//write("tmp leaving " + tmp);
					if(migrating_agents[closest.index] = nil)
					{
						migrating_agents[closest.index] <- list<people>(tmp);
					}else
					{
						migrating_agents[closest.index] << tmp;
					}
				}
			}
		}
		
		
		ask Communication_Agent_MPI
		{
			//write("migrating_people before comm " + migrating_people);
			map<int, people> received_peoples <- MPI_ALLTOALL(migrating_agents);
			//write("received_people from comm " + received_peoples);
			write("received_peoples " + received_peoples);
		}
		
		
		loop migrating_agent over: migrating_agents.pairs
		{
			write("migrating_agent " + migrating_agent);
			loop migrating_agent_to_remove over: migrating_agent.value
			{
				write("migrating_agent_to_remove " + migrating_agent_to_remove);
				remove migrating_agent_to_remove from: my_points; // remove from my point
			}
			loop migrating_agent_to_remove over: migrating_agent.value
			{
				//write("killing " + migrating_agent_to_remove);
				ask migrating_agent_to_remove
				{					
					do die; // kill this agent
				}
			}
		}
		
		write("lenght["+self+"] : " + length(my_points));
		my_points <- my_points where !dead(each);
		location <- mean(my_points collect each.location); // move centroid in the middle of the convex
		convex <- convex_hull(polygon(my_points));
	}
	
	action update_centroid_location
	{
		//write("update_centroid_location self " + self);
		//write("update_centroid_location index " + self.index);
		//write("update_centroid_location location " + self.location);
		//write("update_centroid_location convex " + self.convex);
		
		map<int, list<list<unknown>>> receiving_centroids_data;
		map<int, list<list<unknown>>> sending_centroids_data;
		loop i from: 0 to: MPI_SIZE - 1
		{
			if(i != MPI_RANK)
			{	
				if(sending_centroids_data[i] = nil)
				{
					sending_centroids_data[i] <- list<list<unknown>>([]);
					sending_centroids_data[i] << list<list<unknown>>(list(self.index, self.location, self.convex));
				}else
				{
					sending_centroids_data[i] << list<list<unknown>>(list(self.index, self.location,self.convex));
				}
			}
		}
		ask Communication_Agent_MPI
		{
			//write("sending_centroids_data " + sending_centroids_data);
			receiving_centroids_data <- MPI_ALLTOALL(sending_centroids_data);
			//write("receiving_centroids_data " + receiving_centroids_data);
		}
		
		loop centroids_data_list over: receiving_centroids_data
		{
			//write("list<list<unknown>>(centroids_data_list)" + list<list<unknown>>(centroids_data_list));
			loop centroids_data over: list<list<unknown>>(centroids_data_list)
			{
				int centroid_index <- int(centroids_data[0][0]);
				point centroid_location <- point(centroids_data[1]);
				geometry centroid_convex <- geometry(centroids_data[2]);
				
				//write("centroids_data[0] " + centroid_index);
				//write("centroids_data[1] " + centroid_location);
				//write("centroids_data[2] " + centroid_convex);
				centroid_agent[centroid_index].location <- centroid_location;	
				centroid_agent[centroid_index].convex <- centroid_convex;
				
				//write("centroid_agent[" +centroid_index + "] " + centroid_agent[centroid_index]);
				//write("centroid_agent[" +centroid_index + "] location " + centroid_agent[centroid_index].location);
				//write("centroid_agent[" +centroid_index + "] convex " + centroid_agent[centroid_index].convex);
			}
		}
	}
	
	aspect default
	{
		draw cross(2, 0.5) color: color_kmean;
		draw convex color: rgb(color_kmean,0.2) border: #black;
		
		if(index = MPI_RANK)
		{
			draw "" + length(my_points) + " peoples " font: font('Default', 15, #bold) color: #black;
		}
	}
}

species Communication_Agent_MPI skills:[MPI_SKILL]{} // communication agent with MPI Librairy

experiment distributed type: MPI_EXP
{
	reflex snapshot // take a snapshot of the current distribution model instance
	{
		write("SNAPPING___________________________________ " + cycle);
		ask simulation
		{			
			save (snapshot("people")) to: "../output.log/snapshot/KMEAN/KMEAN" + MPI_RANK + "/people_" + cycle + ".png" rewrite: true;		
		}
	}
	output 
	{
		display people
		{
			graphics "exit" {
				ask continuous_move.main[0].simulation
				{
					loop people_agent over: people
					{				
						draw circle(1) at: people_agent.location color: people_agent.color;	
					}
					loop building_agent over: building
					{
						draw building_agent color: #gray depth: building_agent.height border: #black;
					}
					loop target_agent over: target
					{
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
			species centroid_agent;
		}
		
	}
}
