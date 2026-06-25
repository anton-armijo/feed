## Maps an animation name to its IK influence profile.
## Used in FootIKConfig.animation_profiles array.
class_name AnimIKEntry
extends Resource

@export var animation_name: StringName = &""
@export var profile: IKInfluenceProfile
