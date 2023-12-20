extends CharacterBody2D


const SPEED = 100.0  # 80.0
# const JUMP_VELOCITY = -400.0
const MAX_OBTAINABLE_HEALTH = 400.0

enum STATES { IDLE=0, DEAD, DAMAGED, ATTACKING, CHARGING }

@export var data = {
	"max_health": 60.0,  # 20hp per heart; 5 per fraction
	"health": 60.0,      # Min 60 Max 400
	"money": 0,
	"state": STATES.IDLE,
	"secondaries": [],
}

var inertia = Vector2()
var look_direction = Vector2.DOWN  # (0, 1)
var attack_direction = Vector2.DOWN
var animation_lock = 0.0  # Lock player while playing attack animation
var damage_lock = 0.0
var charge_time = 2.5
var charge_start_time = 0.0


var menu_scene = preload("res://hud.tscn")

var menu_instance = null

@onready var p_HUD = get_tree().get_first_node_in_group("hud")


func get_direction_name():
	return ["right", "down", "left", "up"][
		int(round(look_direction.angle() * 2 / PI)) % 4
	]



func pickup_money(value):
	data.money += value


func _ready():
	menu_instance = menu_scene.instantiate()
	get_tree().get_root().add_child.call_deferred(menu_instance)
	menu_instance.hide()


signal health_depleted

func take_damage(dmg):
	if damage_lock == 0.0:
		data.health -= dmg
		data.state = STATES.DAMAGED
		damage_lock = 0.5
		animation_lock = dmg * 0.005
		# TODO: damage shader
		$AnimatedSprite2D.material.set_shader_parametet("intensity", 0,5)
		if data.health <= 0:
			data.state = STATES.DEAD
			# TODO: play death animation & sound
			await get_tree().create_timer(0.5).timeout
			health_depleted.emit()
		else:
			# TODO: play damage sound
			pass
	pass


func _physics_process(_delta):
	animation_lock = max(animation_lock-_delta, 0.0)
	damage_lock = max(damage_lock-_delta, 0.0)
	
	if animation_lock == 0.0 and data.state != STATES.DEAD:
		# TODO: damage and charging
		if data.state == STATES.DAMAGED and max(damage_lock-_delta, 0.0):
			$AnimatedSprite2D.material = null
		
		if data.state != STATES.CHARGING:
			data.state = STATES.IDLE
		
		var direction = Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_up", "ui_down")
		).normalized()  # Scale to 1 to prevent speed boost
		update_animation(direction)
		if direction.length() > 0:
			look_direction = direction
			velocity = direction * SPEED
		else:
			velocity = velocity.move_toward(Vector2(), SPEED)
		velocity += inertia
		move_and_slide()
		inertia = inertia.move_toward(Vector2(), _delta * 1000.0)
	
	if data.state != STATES.DEAD:
		if Input.is_action_just_pressed("ui_accept"):
			charge_start_time = Time.get_time_dict_from_system().second
			data.state = STATES.CHARGING
		
		if Input.is_action_just_released("ui_accept"):
			var ctime = Time.get_time_dict_from_system().second
			var charge_duration = ctime - charge_start_time
			if charge_duration >= charge_time and data.state == STATES.CHARGING:
				data.state = STATES.IDLE
		if Input.is_action_just_pressed("ui_select"):
			for entity in get_tree().get_nodes_in_group("Interactable"):
				if entity.in_range(self):
					entity.interact(self)
					data.state = STATES.IDLE
					return
	
	if Input.is_action_just_pressed("ui_cancel"):
		menu_instance.show()
		get_tree().paused = true


func update_animation(direction):
	if data.state == STATES.IDLE:
		var a_name = "idle_down"  # Default
		if direction.length() > 0:
			look_direction = direction
			a_name = "walk_"
			if direction.x != 0:
				a_name += "left"
				$AnimatedSprite2D.flip_h = direction.x < 0
			elif direction.y < 0:
				a_name += "up"
			elif direction.y > 0:
				a_name += "down"
			$AnimatedSprite2D.play()
		else:
			if look_direction.x != 0:
				a_name = "idle_left"
				$AnimatedSprite2D.flip_h = look_direction.x < 0
			elif look_direction.y < 0:
				a_name = "idle_up"
			elif look_direction.y > 0:
				a_name = "idle_down"
		
		if $AnimatedSprite2D.animation != a_name:
			$AnimatedSprite2D.animation = a_name
