const [major, minor] = process.versions.node.split(".").map(Number);
if (major < 22 || (major === 22 && minor < 5)) {
  console.error(`web tests need Node >= 22.5 for node:sqlite. This is Node ${process.version}.`);
  process.exit(1);
}
