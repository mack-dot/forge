// Holds a SHARED lock on the database (open read transaction) until killed.
import { DatabaseSync } from "node:sqlite";
const d = new DatabaseSync(process.argv[2]); d.exec("BEGIN"); d.prepare("SELECT COUNT(*) AS n FROM settled").get();
console.log("SHARED"); setInterval(() => {}, 1000);
