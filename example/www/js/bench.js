// Test 9 data: 2,000 synthetic procedure-style items (50 pieces of
// equipment x 40 tasks) and 20 search queries. Deterministic.
const EQUIPMENT = [
  'centrifugal pump', 'air compressor', 'diesel generator', 'conveyor belt', 'forklift',
  'cooling tower', 'chiller', 'boiler', 'gearbox', 'electric motor',
  'hydraulic press', 'overhead crane', 'scissor lift', 'exhaust fan', 'air handling unit',
  'water heater', 'sump pump', 'fire pump', 'backflow preventer', 'steam trap',
  'pressure vessel', 'welding machine', 'lathe', 'milling machine', 'drill press',
  'bench grinder', 'band saw', 'packaging machine', 'palletiser', 'loading dock leveller',
  'roller door', 'automatic gate', 'lift car', 'escalator', 'UPS',
  'switchboard', 'transformer', 'solar inverter', 'battery bank', 'emergency light',
  'smoke detector', 'sprinkler valve', 'eyewash station', 'fume hood', 'cold room',
  'ice machine', 'dishwasher', 'water filter', 'grease trap', 'vacuum pump',
];

const TASKS = [
  ['Daily pre-start check', 'Walk around the {e}, look for leaks, loose guards and damage, and record the check before use.'],
  ['Lubrication', 'Apply the specified grease or oil to every lubrication point on the {e} and wipe off the excess.'],
  ['Vibration check', 'Measure vibration on the {e} bearings and compare with the last reading; rising values mean wear or misalignment.'],
  ['Noise investigation', 'If the {e} sounds rough, grinding or louder than usual, stop it and inspect bearings, couplings and mounts.'],
  ['Overheating check', 'If the {e} runs hot, check ventilation, airflow, load and current draw before restarting.'],
  ['Leak repair', 'Isolate the {e}, release pressure, find the source of the leak and replace the failed seal or fitting.'],
  ['Filter change', 'Shut down the {e}, remove the old filter element, fit a new one and note the date on the housing.'],
  ['Belt and drive check', 'Check drive belts or chains on the {e} for wear, cracking and tension, and adjust or replace.'],
  ['Electrical isolation', 'Lock out and tag out the {e} at the isolator and prove it dead before opening any panel.'],
  ['Thermal scan', 'Scan the {e} connections and terminals with an infrared camera and tighten anything running hot.'],
  ['Calibration', 'Compare the {e} gauges and sensors with a reference instrument and adjust any that drift.'],
  ['Cleaning', 'Isolate the {e} and remove dust, debris and build-up from surfaces, vents and moving parts.'],
  ['Corrosion inspection', 'Inspect the {e} frame, fixings and pipework for rust and pitting, and treat or replace affected parts.'],
  ['Safety guard check', 'Confirm every guard and interlock on the {e} is fitted and stops the machine when opened.'],
  ['Emergency stop test', 'Press each emergency stop on the {e} while running and confirm it stops immediately and needs a manual reset.'],
  ['Alarm test', 'Trigger the {e} alarms and confirm they sound locally and reach the monitoring panel.'],
  ['Fluid level check', 'Check oil, coolant or hydraulic fluid levels on the {e} and top up with the correct grade.'],
  ['Pressure test', 'Run the {e} to working pressure, watch the gauge for drop-off and check the relief valve lifts.'],
  ['Alignment', 'Use a laser tool to check shaft or rail alignment on the {e} and shim to tolerance.'],
  ['Fastener torque check', 'Re-torque bolts and fixings on the {e} to the values in the manual and mark them.'],
  ['Wear part replacement', 'Replace worn blades, pads, liners or brushes on the {e} before they reach the wear limit.'],
  ['Software and controller check', 'Check the {e} controller for fault codes, back up settings and apply approved firmware.'],
  ['Battery check', 'Test the {e} backup or starter batteries for voltage and condition and clean the terminals.'],
  ['Hose inspection', 'Inspect hoses on the {e} for cracks, bulges and chafing and replace any that are damaged.'],
  ['Seal inspection', 'Check door, shaft and housing seals on the {e} for leaks, hardening or tears.'],
  ['Temperature log', 'Record the {e} operating temperatures each shift and report readings outside the range.'],
  ['Start-up procedure', 'Open supply valves, check interlocks and start the {e} in the order given in the manual.'],
  ['Shutdown procedure', 'Unload the {e}, stop it in sequence, isolate supplies and leave it in a safe state.'],
  ['Annual service', 'Carry out the full manufacturer service on the {e} and update the maintenance record.'],
  ['Fault finding', 'If the {e} will not start, check power, fuses, interlocks and controller faults in that order.'],
  ['Spare parts check', 'Confirm critical spares for the {e} are in stock and reorder anything below minimum.'],
  ['Operator training check', 'Confirm everyone using the {e} has a current competency record.'],
  ['Risk assessment review', 'Review the {e} risk assessment and update controls after any incident or change.'],
  ['Noise level measurement', 'Measure sound levels near the {e} and post hearing protection signs where required.'],
  ['Drain and flush', 'Drain the {e}, flush out sediment and refill with clean fluid.'],
  ['Earth continuity test', 'Test earth continuity and insulation resistance on the {e} wiring and record the results.'],
  ['Label and signage check', 'Check that warning labels, rating plates and signs on the {e} are present and readable.'],
  ['Access and housekeeping', 'Keep the area around the {e} clear, dry and well lit for safe access.'],
  ['Spill response', 'If fluid leaks from the {e}, contain it with the spill kit and dispose of absorbent as hazardous waste.'],
  ['Decommissioning', 'Isolate, drain and tag the {e} before removal and record its disposal.'],
];

window.benchItems = () => {
  const items = [];
  EQUIPMENT.forEach((e, i) =>
    TASKS.forEach(([task, body], j) => {
      const title = `${e.charAt(0).toUpperCase() + e.slice(1)}: ${task.toLowerCase()}`;
      items.push({ id: `b${String(i * TASKS.length + j + 1).padStart(4, '0')}`, text: `${title}. ${body.replace('{e}', e)}`, metadata: title });
    }),
  );
  return items;
};

window.BENCH_QUERIES = [
  'pump is making a grinding noise',
  'generator battery keeps going flat',
  'compressor leaking oil',
  'how do I safely isolate the crane',
  'motor is too hot to touch',
  'forklift brakes feel soft',
  'chiller alarm will not stop',
  'conveyor belt is slipping',
  'boiler pressure keeps dropping',
  'smoke detector beeping',
  'fan is wobbling and shaking',
  'lathe guard does not stop the machine',
  'water heater makes rusty water',
  'cold room is not cold enough',
  'how often do we service the escalator',
  'sprinkler valve test procedure',
  'solar inverter shows a fault code',
  'drill press emergency stop',
  'grease trap overflowing',
  'UPS batteries replacement',
];
