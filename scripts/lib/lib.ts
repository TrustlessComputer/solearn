import fs from "fs";
import path from "path";

export function stringifyJSON(obj: any) {
    return JSON.stringify(obj, (_, v) => typeof v === 'bigint' ? v.toString() : v);
}

export function saveFile(dir: string, name: string, content: string) {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(path.join(dir, name), content);
}