local module = {}

export type TerrainChunkClassCreateInfo = {
    name: string,
    reference_part: BasePart,
    edits: {string}?,
    entities: {any}?,
}

export type CameraClassCreateInfo = {
    name: string,
    priority: number,
}

export type BaseGunCreateInfo = {
    name: string,
}

export type BaseToolCreateInfo = {
    name: string,

    holster_reference: Instance?,
    model_reference: Instance?,
}

return module