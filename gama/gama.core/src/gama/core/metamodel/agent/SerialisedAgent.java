/*******************************************************************************************************
 *
 * SerialisedAgent.java, in gama.core, is part of the source code of the GAMA modeling and simulation platform
 * .
 *
 * (c) 2007-2024 UMI 209 UMMISCO IRD/SU & Partners (IRIT, MIAT, TLU, CTU)
 *
 * Visit https://github.com/gama-platform/gama for license information and contacts.
 *
 ********************************************************************************************************/
package gama.core.metamodel.agent;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import gama.core.common.interfaces.IKeyword;
import gama.core.common.util.RandomUtils;
import gama.core.kernel.experiment.ExperimentAgent;
import gama.core.kernel.experiment.ExperimentPlan.ExperimentPopulation;
import gama.core.kernel.model.GamlModelSpecies;
import gama.core.kernel.root.PlatformAgent;
import gama.core.kernel.simulation.SimulationAgent;
import gama.core.kernel.simulation.SimulationPopulation;
import gama.core.metamodel.population.IPopulation;
import gama.core.metamodel.population.ISerialisedPopulation;
import gama.core.metamodel.population.SerialisedGrid;
import gama.core.metamodel.population.SerialisedPopulation;
import gama.core.metamodel.topology.grid.GridPopulation;
import gama.core.metamodel.topology.grid.IGridAgent;
import gama.core.runtime.IScope;
import gama.core.runtime.exceptions.GamaRuntimeException;
import gama.core.util.file.json.Json;
import gama.core.util.file.json.JsonGamlAgent;
import gama.core.util.file.json.JsonValue;
import gama.dev.DEBUG;
import gama.gaml.descriptions.ModelDescription;

/**
 * The Class SerialisedAgent.
 *
 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
 * @date 31 juil. 2023
 */
public record SerialisedAgent(int index, String species, Map<String, Object> attributes,
		Map<String, ISerialisedPopulation> innerPopulations, UUID uuid) implements ISerialisedAgent {

	static
	{
		DEBUG.ON();
	}

	/** All the attributes that are not interesting to serialise for regular agents */
	public static Set<String> NON_SERIALISABLE = Set.of(IKeyword.MEMBERS, IKeyword.AGENTS, /*IKeyword.LOCATION,*/
			IKeyword.HOST, IKeyword.PEERS, IKeyword.EXPERIMENT, IKeyword.WORLD_AGENT_NAME, SimulationAgent.TIME,
			PlatformAgent.MACHINE_TIME, SimulationAgent.DURATION, SimulationAgent.AVERAGE_DURATION,
			SimulationAgent.TOTAL_DURATION, IKeyword.INDEX);

	/** All the attributes that are not interesting to serialise for grid agents */
	public static Set<String> GRID_NON_SERIALISABLE = Set.of(IKeyword.GRID_X, IKeyword.GRID_Y, IKeyword.NEIGHBORS);

	/** The Constant KEY. */
	public static final String HISTORY_KEY = "**history**";

	/** The node key. */
	public static final String SERIALISE_HISTORY = "**serialise_history**";

	/**
	 * Creates a new SerialisedAgent object.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param agent
	 *            the agent
	 * @return the serialised agent
	 * @date 8 août 2023
	 */
	public static SerialisedAgent of(final IAgent target, final boolean serializePopulations) {

		//DEBUG.OUT("SerialisedAgent of " + target);
		int index = target.getIndex();
		String species = target.getSpeciesName();
		Map<String, Object> attributes = filterAttributes(target, target instanceof IGridAgent,
				target.getAttributes(true), serializePopulations);
		Map<String, ISerialisedPopulation> populations = filterPopulations(target, target instanceof IGridAgent,
				target.getAttributes(true), serializePopulations);
		//DEBUG.OUT("SerialisedAgent getUUID " + target.getUUID());
		SerialisedAgent result = new SerialisedAgent(index, species, attributes, populations, target.getUUID());
		if (target instanceof SimulationAgent sa && !shouldSerializeHistory(sa)) {
			result.attributes().remove(HISTORY_KEY);
		}
		return result;
	}

	/**
	 * Of.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param index
	 *            the index
	 * @param species
	 *            the species
	 * @param attributes
	 *            the attributes
	 * @return the serialised agent
	 * @date 7 nov. 2023
	 */
	public static SerialisedAgent of(final int index, final String species, final Map<String, Object> attributes) {
		DEBUG.OUT("of2 ");
		return new SerialisedAgent(index, species, attributes, Collections.EMPTY_MAP, null);
	}

	/**
	 * Filter populations.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param target
	 *            the target
	 * @param b
	 *            the b
	 * @param m
	 *            the m
	 * @return the map
	 * @date 29 oct. 2023
	 */
	private static Map<String, ISerialisedPopulation> filterPopulations(final IAgent target, final boolean b,
			final Map<String, Object> m, final boolean serializePopulations) {

		//DEBUG.OUT("filterPopulations ");
		if (!serializePopulations) return Collections.EMPTY_MAP;
		Map<String, ISerialisedPopulation> map = new HashMap<>();
		for (Map.Entry<String, Object> entry : m.entrySet()) {
			Object v = entry.getValue();
			if (v instanceof IPopulation<?> p) {
				map.put(entry.getKey(),
						p.isGrid() ? new SerialisedGrid((GridPopulation) p) : new SerialisedPopulation(p));
			}
		}
		return map;
	}

	/**
	 * Gets the index.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @return the index
	 * @date 6 août 2023
	 */
	@Override
	public int getIndex() { return index; }

	/**
	 * Filter map.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param m
	 *            the m
	 * @return the object
	 * @date 31 juil. 2023
	 */
	@SuppressWarnings ("unchecked")
	public static Map<String, Object> filterAttributes(final IAgent agent, final boolean isGrid,
			final Map<String, Object> m, final boolean serializePopulations) {

		//DEBUG.OUT("filterAttributes " + m);
		Map<String, Object> map = new HashMap<>();
		for (Map.Entry<String, Object> entry : m.entrySet()) {
			String k = entry.getKey(); //
			Object v = entry.getValue();
			if (NON_SERIALISABLE.contains(k) || isGrid && GRID_NON_SERIALISABLE.contains(k)
					|| serializePopulations && v instanceof IPopulation) {
				continue;
			}
			map.put(k, v);
		}
		boolean isSim = agent instanceof SimulationAgent;
		if (isSim) {
			SimulationAgent sim = (SimulationAgent) agent;
			map.put(IKeyword.SEED, sim.getSeed());
			map.put(IKeyword.RNG, sim.getRng());
			map.put(SimulationAgent.USAGE, sim.getUsage());
			map.put(SimulationAgent.CYCLE, sim.getClock().getCycle());
		}
		if (!isGrid) { map.put(IKeyword.SHAPE, agent.getGeometry()); }
		map.put(IKeyword.NAME, agent.getName());
		map.put(IKeyword.LOCATION, agent.getLocation());
		//DEBUG.OUT("agent.getLocation() " + agent.getLocation());
		//DEBUG.OUT("filtered Attributes map result " + map);
		//DEBUG.OUT("cotnains,??? " + map.containsKey(IKeyword.LOCATION));
		return map;
	}

	@Override
	public Object getAttributeValue(final String var) {

		DEBUG.OUT("getAttributeValue " + var);
		return attributes.get(var);
	}

	@Override
	public void setAttributeValue(final String var, final Object val) {

		DEBUG.OUT("setAttributeValue " + var + " :: " + val);
		attributes.put(var, val);
	}

	/**
	 * @param scope
	 *            Restores the saved agent as a member of the target population.
	 *
	 * @param targetPopulation
	 *            The population that the saved agent will be restored to.
	 * @return
	 * @throws GamaRuntimeException
	 */
	@Override
	public IAgent restoreInto(final IScope scope, final IPopulation<? extends IAgent> targetPopulation)
			throws GamaRuntimeException {

		DEBUG.OUT("restoreIntorestoreInto");
		final List<Map<String, Object>> agentAttrs = new ArrayList<>();
		agentAttrs.add(attributes);
		DEBUG.OUT("restireint : " + agentAttrs);
		final List<? extends IAgent> restoredAgents = targetPopulation.createAgents(scope, 1, agentAttrs, true, true);
		IAgent result = restoredAgents.get(0);
		restoreAs(scope, result);
		return result;
	}

	/**
	 * Restore as.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param scope
	 *            the scope
	 * @param agent
	 *            the agent
	 * @return the i agent
	 * @date 31 oct. 2023
	 */
	@Override
	public void restoreAs(final IScope scope, final IAgent agent) {
		// Update attributes and micropopulations

		DEBUG.OUT("agent to recreate : " + agent);
		DEBUG.OUT("agent to recreat class : " + agent.getClass());
		DEBUG.OUT("agent attributes() : " + attributes());
		DEBUG.OUT("agent ahshsahsah() : " + uuid);
		
		// optional
		agent.setUUID(uuid.toString()); // set UUID ??
		agent.setOriginalSimulationID(agent.getOriginalSimulationID()); // !!! set originalRankID
		// optional
		
		DEBUG.OUT("agent agent.getHashcode() : " + agent.getUUID());
		DEBUG.OUT("agent agent.getOriginalSimulationID() : " + agent.getOriginalSimulationID());
		
		attributes().forEach((name, v) -> { agent.setDirectVarValue(scope, name, v); });
		
		if (agent instanceof IMacroAgent host && innerPopulations != null) {
			innerPopulations.forEach((name, v) -> {
				IPopulation<? extends IAgent> pop = host.getMicroPopulation(name);
				if (pop != null) {
					if (v instanceof SerialisedGrid sg) {
						sg.restoreAs(scope, pop);
					} else if (v instanceof SerialisedPopulation sp) { sp.restoreAs(scope, pop); }
				}
			});
			// Update simulation-specific variables
			if (agent instanceof SimulationAgent sim) {
				final Map<String, Object> attr = attributes();
				Double seedValue = (Double) attr.remove(IKeyword.SEED);
				String rngValue = (String) attr.remove(IKeyword.RNG);
				Integer usageValue = (Integer) attr.remove(SimulationAgent.USAGE);
				sim.setRandomGenerator(new RandomUtils(seedValue, rngValue));
				sim.setUsage(usageValue);
				// Update Clock
				final Integer cycle = (Integer) sim.getAttribute(SimulationAgent.CYCLE);
				sim.getClock().setCycleNoCheck(cycle);

			}
		}
	}

	@Override
	public JsonValue serializeToJson(final Json json) {

		DEBUG.OUT("serializeToJson of " + json);
		JsonGamlAgent obj = (JsonGamlAgent) json.agent(species, index).add("attributes", attributes);
		if (innerPopulations != null && !innerPopulations.isEmpty()) { obj.add("populations", innerPopulations); }
		return obj;
	}

	/**
	 * Recreate in.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param scope
	 *            the scope
	 * @return the i agent
	 * @date 30 oct. 2023
	 */
	public IAgent recreateIn(final IScope scope) {

		DEBUG.OUT("recreateIn of " + scope);
		IPopulation<?> p = scope.getSimulation().getPopulationFor(species);
		DEBUG.OUT("population to recreat into t : " + p);
		
		if(p == null)
		{
			DEBUG.OUT("species to recreate : " + species);
			DEBUG.OUT("scope.getSimulation()11 : " + scope.getSimulation().getMicroPopulation(species));
			DEBUG.OUT("scope.getSimulation()222 " + scope.getSimulation().getAgents(scope));
			
			DEBUG.OUT("recreateIn null so we look for external pop");
			final ModelDescription micro = scope.getModel().getDescription();
			DEBUG.OUT("micro model " + micro);
			DEBUG.OUT("micro model exp names " + micro.getExperimentNames());
			DEBUG.OUT("ddd " + micro.getMicroSpecies());
			
			SimulationAgent mainSimulationAgent = (SimulationAgent) scope.getSimulation().getPopulation().get(0);
			for(var auto : scope.getModel().getMicroSpecies())
			{
				DEBUG.OUT("current azdaza " + auto.getName());
				DEBUG.OUT("current pop ccc" + auto.getClass());
				if(auto instanceof GamlModelSpecies microModel)
				{
					DEBUG.OUT("microModel.getMicroSpeciesNames() : " + microModel.getMicroSpeciesNames());
					
					if(microModel.getMicroSpeciesNames().contains(species))
					{
						p = microModel.getAllSpecies().get(species).getPopulation(scope);
						DEBUG.OUT("ppoppdkzdoze " + p );
					}
				}
			}
		}
		
		//DEBUG.OUT("size of pop pre : " + p.size());

		//	DEBUG.OUT("agent uuid to recreate : " + this.uuid);
		
		if (p == null)
			throw GamaRuntimeException.error("No population named" + species + " exist in this simulation", scope);

		//DEBUG.OUT("reacreate in this.attributes  : " + this.attributes);
		//DEBUG.OUT("reacreate in index : " + index);
		IAgent a = p.getOrCreateAgent(scope, index, this.attributes, this.uuid());
		//DEBUG.OUT("p.getOrCreateAgent " + a);
		//DEBUG.OUT("p.getOrCreateAgent new agent index" + a.getIndex());
		restoreAs(scope, a);
		return a;
	}

	/**
	 * Should serialize history.
	 *
	 * @author Alexis Drogoul (alexis.drogoul@ird.fr)
	 * @param sim
	 *            the sim
	 * @return true, if successful
	 * @date 22 oct. 2023
	 */
	static boolean shouldSerializeHistory(final SimulationAgent sim) {

		DEBUG.OUT("recreashouldSerializeHistoryteIn");
		return sim.hasAttribute(SERIALISE_HISTORY) && (Boolean) sim.getAttribute(SERIALISE_HISTORY);
	}

}

