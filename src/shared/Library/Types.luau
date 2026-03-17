local module = {}

export type TerrainChunkClassCreateInfo = {
    name : string;
    reference_part : BasePart;
    edits : {string}?;
    entities : {any}?;
};

export type CameraClassCreateInfo = {
    name: string;
    priority: number;
};

export type BaseGunCreateInfo = {
    name : string;
};

export type BaseToolCreateInfo = {
    name : string;
    on_give: () -> ();
    on_equip: () -> ();
    on_activation: () -> ();
    on_unequip: () -> ();

    holster_reference: Instance?;
    model_reference: Instance?;
};

return module