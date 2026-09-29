# Configuration

Local values override global values. Declared defaults apply last.

## Global

| Setting | Description | Default | Constraints |
| --- | --- | --- | --- |
| `checkForUpdates` | Whether the tool may check for updates. | `true` | `{"type":"boolean","description":"Whether the tool may check for updates.","default":true}` |
| `port` | Port on which the application listens. | `8080` | `{"type":"integer","minimum":1,"maximum":65535,"description":"Port on which the application listens.","default":8080,"examples":[8080,9000]}` |

## Local

| Setting | Description | Default | Constraints |
| --- | --- | --- | --- |
| `checkForUpdates` | Whether the tool may check for updates. | `true` | `{"type":"boolean","description":"Whether the tool may check for updates.","default":true}` |
| `features` | Enabled optional features. | `[]` | `{"type":"array","items":{"type":"string"},"description":"Enabled optional features.","default":[]}` |
| `port` | Port on which the application listens. | `8080` | `{"type":"integer","minimum":1,"maximum":65535,"description":"Port on which the application listens.","default":8080,"examples":[8080,9000]}` |
| `projectName` | Display name of this project. | `null` | `{"anyOf":[{"type":"string","minLength":1},{"type":"null"}],"description":"Display name of this project.","default":null}` |
