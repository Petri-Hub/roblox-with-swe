# TODO: Headless Roblox asset bridge

Build a small, cloud-only MCP server for Creator Store asset discovery and file delivery. It should expose asset tools to Pepper without exposing a Roblox API key or any Studio connection tools.

## Roblox endpoints and permissions

| Task | Endpoint | API key scope |
|---|---|---|
| Search models, meshes, audio, and other Creator Store assets | `POST https://apis.roblox.com/toolbox-service/v2/assets:search` | `creator-store-product:read` |
| Inspect a result's creator, price, description, and script count | `GET https://apis.roblox.com/toolbox-service/v2/assets/{id}` | `creator-store-product:read` |
| Get an asset thumbnail | `GET https://thumbnails.roblox.com/v1/assets` | None for the public thumbnail endpoint |
| Obtain a model file's download location | `GET https://apis.roblox.com/asset-delivery-api/v1/assetId/{assetId}` | `legacy-asset:manage` |

The current project key returns `403 Scope not authorized` for authenticated Creator Store search and Asset Delivery. `asset:read` is not a substitute for either scope. An unauthenticated `GET` search and the old public Asset Delivery URL worked during this prototype, but Roblox marks the GET search as not recommended and has announced authentication requirements for legacy asset delivery. Do not make those public paths the bridge's contract.

Sources: [Creator Store API](https://create.roblox.com/docs/cloud/reference/features/creator-store), [Open Cloud scopes](https://create.roblox.com/docs/cloud/reference/scopes), [asset delivery change](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403), [thumbnails API](https://create.roblox.com/docs/cloud/reference/features/thumbnails).

## MCP tools

- `search_assets(query, category, page_token, free_only)`: return a short list with asset IDs, names, creators, prices, script counts, and the next page token.
- `get_asset_details(asset_id)`: return the listing details and thumbnail URL for review.
- `prepare_asset_download(asset_id)`: use a separate key with `legacy-asset:manage` and return Roblox's temporary HTTPS CDN `location`, plus its expiry when available. Do not return a path on the MCP server's filesystem.

Keep the tools limited to this asset workflow: no Studio bridge, arbitrary URL fetch, or generic Open Cloud request. Keep both Roblox keys in the MCP service, outside Pepper's Modal sandbox; give the search key only `creator-store-product:read`. The download location is a temporary download capability, so avoid printing or committing its full URL.

## Why Pepper can use the CDN URL without the API key

1. The MCP server uses its `legacy-asset:manage` key to call Roblox's [Asset Delivery API](https://create.roblox.com/docs/cloud/reference/features/assets) for one asset ID. Roblox responds with a `location` URL on its CDN; it does not send the model bytes in this response.
2. The MCP tool returns that URL to Pepper. Its query parameters include a token and expiry, so the URL itself temporarily authorizes that one download. Pepper does not need the Roblox API key for the CDN request. Treat the full URL as a temporary secret: do not print it in logs or commit it.
3. Pepper's terminal makes the second HTTPS request from inside Modal and saves the returned bytes in its checkout. That is how the asset crosses the Hermes-to-Modal filesystem boundary. The URL must be fetched before it expires.

Roblox describes the [two-request `location` flow](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403?page=4). We verified a no-key CDN fetch for the free Forest Pack using the public legacy metadata endpoint; the scoped Open Cloud first request and Pepper's actual Modal handoff still need testing after the key gains `legacy-asset:manage`.

## Hermes-to-Modal file handoff

Pepper's MCP tools run with Hermes in the homelab, while her terminal and repository checkout run in a disposable Modal Sandbox. A file written by an MCP tool to a homelab path is therefore not in Pepper's checkout. This is consistent with the earlier FAM PDF path problem; confirm its exact cause when testing this bridge.

Preferred flow: Hermes calls `prepare_asset_download`, then Pepper's terminal fetches the returned Roblox CDN URL **inside the active Modal Sandbox** and writes the model into its checkout. Modal Sandboxes allow outbound HTTPS by default. This avoids passing a large binary through a text tool result or assuming the two machines share a filesystem. Fetch promptly because the URL expires. Once selected and checked, commit the model to Git so the asset survives the sandbox.

If the CDN URL cannot be fetched from the sandbox, investigate copying the bytes into that specific live sandbox with Modal's [Sandbox Filesystem API](https://modal.com/docs/guide/sandbox-files). A shared path alone is not a transfer mechanism; large base64 tool results are a poor fit for Pepper's current file-tool limit. See [Pepper's Modal setup](https://github.com/Petri-Hub/pepper/blob/main/profiles/pepper/CONFIG.md) and [Modal networking](https://modal.com/docs/guide/sandbox-networking).

## Done when

- Pepper can search and inspect a free model through the MCP server without any Studio connection or Roblox key in the sandbox.
- Pepper can download a selected model into a Modal checkout, handle any compression in the response, verify its actual `.rbxm` or `.rbxmx` contents, build it with Rojo, and commit it.
- A real Hermes-to-Modal test confirms the downloaded file exists in the sandbox, not only on the homelab host; OCALE verifies any asset used by the game.
