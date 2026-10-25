// One-off: fix RU hub art lines and write data/station_communities_en.json.
const fs = require('fs');
let t = fs.readFileSync('data/station_communities.json', 'utf8');
const R = [
  ["Звёздный потолок главного зала, круглые часы над справочной.", "Высокий тёмный зал, круглые часы над справочной, закрытые ворота."],
  ["Солдаты, полиция и диспетчеры. Управляют расписанием, берут пошлины, держат порядок.", "Служащие терминала, транспортная охрана и контролёры. Ведут расписание и ведомость, берут пошлины, держат порядок."],
  ["Диспетчеры помнят, чьи имена он внёс в графу «лишние», когда закрывали бункеры.", "Служащие помнят, чьи имена он внёс в графу «лишние», когда закрывали бункеры."],
  ["Готические арки недостроенного собора.", "Общая кухня под лестницей с цепью на выходе."],
  ["Колонны старой биржи, масляные лампы, доска курсов мелом.", "Весы и мешки зерна на столе расчётов под одной лампой."],
  ["\"art\": \"Часовая башня старого банка.\"", "\"art\": \"Проводник с лампой у устья тёмного тоннеля.\""],
  ["Синод Тоннеля", "Синод тоннеля"],
  ["Чистая Линия", "Закрытая Линия"],
  ["Ультранационалистическая милиция на окраине сети. Набеги и оборона.", "Милиция окраины, не пускает чужих. Набеги и оборона."],
];
for (const [a, b] of R) {
  if (!t.includes(a)) console.log('MISS', a);
  t = t.split(a).join(b);
}
fs.writeFileSync('data/station_communities.json', t);
const ru = JSON.parse(t).stations;

const en = {
  northgate: ["Iron Directorate", "Terminal clerks, transit guards and comptrollers. They keep the timetable and the ledger, take tolls, hold order.", "Lionel Abelard keeps the single ration list. The clerks remember whose names he put in the column marked 'surplus' when the bunkers were closed.", "A tall dark hall, a round clock over the information booth, the gates shut."],
  foundry: ["Children of the Machine", "Transhumanists at the old boilers. They sew iron into their bodies and call machines the heirs of people.", "Someone really has learned to hear current. Or gone mad.", "Old boilers, a round arena above the station."],
  plaza: ["Communards", "Shared storehouses, everything split evenly, a meeting every evening.", "The old guard against those who quietly trade with the Exchange.", "An equestrian statue in the square, red cloths with no writing."],
  central: ["Free City", "Performers, gamblers and spies of every faction. Entertainment, rumours, deals.", "Once a year they elect the Mayor of the Metro.", "Dead screens and neon without letters, a staircase for a stage."],
  market: ["Keepers of the Spring", "Water carriers with a monopoly on the only clean water.", "The water gets dearer every week. Someone is quietly poisoning it.", "Cast-iron fronts, barrels and ladles."],
  riverside: ["Sisters of the Garden", "A women's commune of agronomists and a seed bank. Their aim: one of their own as Mayor of the Metro.", "Everyone wants the seeds, and the sisters will not sell.", "Glass greenhouses, beds under lamps."],
  southdepot: ["The Depot", "Crews and workers of the depot on the Coney line. They kept the track and the light, and the cars became their homes.", "Bernie Shaw keeps quiet about the order burned at Stillwell. The young demand the shift archive be opened.", "A Ferris wheel and wooden coasters above, cars turned into homes in the depot."],
  westfield: ["The Closed Line", "A militia on the edge of the network that lets no strangers in. Raids and defence.", "Antagonists: you cannot talk them round, only hold them off or break them.", "The stands of a dead racetrack, flooded pens."],
  brickworks: ["The Lamplighters", "A transfer camp of Niki Ortega's guides along the dark tracks. The camp moves; the toll is paid in food.", "The path is not free: those who cannot pay are led more slowly. Many fear the toll will become a lawful tax.", "A guide with a lantern at the mouth of a dark tunnel."],
  library: ["The Scholars", "Professors and engineers from the technical schools. They mend clocks, argue about the sky, teach the children.", "They will be the first to notice that something is wrong with the Silence.", "Brick lecture halls, boards covered in formulas."],
  observatory: ["Riverfolk", "Fishermen and boatmen at the shaft to the river, water smugglers.", "On quiet nights you can hear water overhead. And someone's footsteps.", "Stone piers of the Brooklyn Bridge."],
  trampark: ["Free Exchange", "Seven houses of the Rate Council keep a shared rate, credit and supply. Marcel Toussaint speaks for them and writes other people's debts on his own forearm.", "One of the seven elders of the Rate Council is secretly trading with the bunker.", "Weighing scales and sacks of grain on the counting table under a single lamp."],
  eastwater: ["The Breathers", "Filter keepers with the biggest lungs in the south. They sell air by the ticket.", "Whoever holds the filters holds the south.", "The old park railing, a customs house with a colonnade."],
  chapel: ["Synod of the Tunnel", "Shelters, orderlies and Dorothy Chen's quiet room. Shared kitchens and an infirmary have become a community of faith.", "Dorothy Chen is seen in the shelter every day. But she lets no one hear the recording of the surface wind, not even her own orderlies.", "A shared kitchen under a staircase, a chain across the exit."],
  garden: ["Slowwalkers", "Mushroom growers in a dead-end tunnel. Sleep more, breathe less, live longer.", "Poor and content. For some reason no one there falls ill.", "An elevated line overhead, mushroom beds in the dark."],
  stadium: ["Free Word", "Liberals and students: a newspaper, a debating club, a jury court.", "They argue about freedom while the enemy is at the gate.", "A brownstone college building, a printing press."],
  harbor: ["The Guild", "Thieves and middlemen. A market with no questions and no receipts.", "Something went missing? Then it is already on a counter here.", "Tenements with fire escapes, a steel bridge."],
  dockyard: ["Last Precinct", "Cops and federal agents by the old courthouses. They hold back disorder for a fee.", "A corrupt captain against an honest agent. You decide whom to back.", "The colonnade of the courthouse and the municipal building."],
  quarry: ["Diggers", "Copper miners in a dead substation. They know every passage.", "They will sell the map of the tunnels to whoever pays most.", "An old seaport, masts of sailing ships."],
  mill: ["Swineherds", "Quiet workers: pigs knee-deep in water, smoked meat, no politics.", "They feed half the line, and everyone wants to take them over.", "Brick warehouses by the water, smoking sheds."],
  clocktower: ["The Hoarders", "They drag home anything left lying about. Cramped, rats, but rich.", "They can find any thing. They just do not want to sell it.", "A maze of stalls, mountains of junk up to the ceiling."],
  archive: ["The Floor bunker", "Officials who still hold planning meetings and write a quarterly budget.", "Documents: the burst was predicted months ahead.", "A closed 1904 station: tiled vaults, glass lanterns."],
  vault: ["The Quarantine bunker", "A garrison that waited for a war and now guards an emptiness.", "Weapons and the lists of those let inside.", "An old loop with a view of the harbour and the Statue of Liberty."],
  signal: ["Signal Post", "Hermit radio amateurs.", "Cables to the surface and someone's answers on the air.", "Antennas made of rails, walls of radio tubes."],
  oldcommand: ["The Observatory bunker", "Scientists who warned and were not heard.", "The full picture of the Silence and the way to the Exodus.", "Old cars of different eras on a closed platform."],
};
const out = {
  _note: 'English text for data/station_communities.json (same station ids). Fields: community, who, conflict, art. The UI uses these when the game language is English; the Russian fields stay for Russian.',
  stations: {},
};
for (const [k, v] of Object.entries(en)) {
  if (!ru[k]) console.log('NOID', k);
  out.stations[k] = { community: v[0], who: v[1], conflict: v[2], art: v[3] };
}
for (const k of Object.keys(ru)) if (!en[k]) console.log('MISSING EN', k);
fs.writeFileSync('data/station_communities_en.json', JSON.stringify(out, null, 2) + '\n');
console.log('done', Object.keys(out.stations).length);
