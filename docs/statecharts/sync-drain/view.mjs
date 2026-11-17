export const title = "A new recipe and its first step, made offline";
export const state = (v) => {
  const q = new Set(v.queued);
  const x = q.has("X"), y = q.has("Y");
  if (!x && !y) return "Recipe and step saved on the server";
  if (x && y) return v.yErr ? "Both waiting, the step shows an error" : "Recipe and step waiting to send";
  if (x) return "Step saved, recipe still waiting";
  if (v.yErr) return "Recipe saved, the step shows an error";
  return v.yRef === "real" ? "Recipe saved, step waiting" : "Recipe saved, step still points at the temporary recipe";
};
export const group = (v) => {
  const q = new Set(v.queued);
  if (v.yErr || (!q.has("X") && q.has("Y") && v.yRef !== "real")) return "broken";
  if (q.size === 0) return "done";
  return "waiting";
};
export const colors = { broken: "orange", done: "teal", waiting: "blue" };
const who = (from, to) => {
  const ds = Object.keys(from.pc).filter((d) => JSON.stringify(from.pc[d]) !== JSON.stringify(to.pc[d]) || from.runs[d] !== to.runs[d]);
  return ds.length === 1 ? (ds[0] === "Siri" ? "Siri" : "the app") : "a sync";
};
export const step = (action, from, to) => {
  const w = who(from, to);
  switch (action) {
    case "ServerCreatesRecipe": return `the server creates the recipe (${w})`;
    case "AcceptedEditLeavesQueue": return `the recipe leaves the queue (${w})`;
    case "ServerAddsStep": return `the server adds the step (${w})`;
    case "ServerRefusesStep": return `the server refuses the step, unknown recipe (${w})`;
    case "ServerSaysTryLater": return `the server says try later (${w})`;
    case "DrainWritesBack": return `${w} saves what is left to send`;
    case "TheAppQuits": return "the app is closed";
    case "ASyncStarts": return `${w} starts a sync`;
    case "ServerSaysTryLaterForStep": return `the network drops the step (${w})`;
    case "XSkipped": return `${w} skips the recipe, already sent`;
    case "YSkipped": return `${w} skips the step, already sent`;
    case "YWaits": return `${w} holds the step behind the recipe`;
    case "Done": return null;
    default: return action;
  }
};
