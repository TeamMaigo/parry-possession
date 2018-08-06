extends KinematicBody2D

var frame = 0
var direction = randi() % 4
var moveDir = Vector2(0,0)
export var MOTION_SPEED = 100
var canSeePlayer = false
export (int) var detect_radius = 300
var usesVision = true
var target
var degreesPerFrame = 4
onready var rotationSpeed = deg2rad(degreesPerFrame)
var velocity
export (PackedScene) var BulletType
export var bulletSpeed = 10
onready var timer = get_node("ShootTimer")
var can_shoot = false
export (float) var fire_rate = 1  # delay time (s) between bullets
var lastKnownPlayerPos
export(String, "singleFire", "shotgun") var fireType
export var respawns = true
export var hp = 1
var bulletOffset = 50
export var bulletRotationSpeed = 1.0 # degrees per frame
export var bulletConeDegrees = 40.0 # Bullet cone of vision (this number is cone of vision degrees, and is 40 both ways)
export var bulletDecayTime = 10.0 # Seconds before bullet becomes linear
export var angleBulletUpdateDelay = 1.0 #seconds

signal enemyDeath

func _ready():
	$Visibility.show()
	if Global.currentScene+name in Global.destroyedObjects:
		queue_free()
	var shape = CircleShape2D.new()
	shape.radius = detect_radius
	$Visibility/CollisionShape2D.shape = shape
	set_physics_process(true)
	waitToShoot(fire_rate)

func _physics_process(delta):
	if target:
		canSeePlayer = checkForPlayer()
		if canSeePlayer:
			lastKnownPlayerPos = target.position
			#rotateTowardsPlayer() # Not currently used
			if can_shoot:
				if fireType == "singleFire":
					shootBulletAtTarget(target.position)
				if fireType == "shotgun":
					shootShotgunAtTarget(target.position)

	movement_loop()

func movement_loop():
	if lastKnownPlayerPos:
		moveDir = (lastKnownPlayerPos - position).normalized()
		var motion = moveDir.normalized() * MOTION_SPEED
		if (lastKnownPlayerPos - position).length() > 5:
			move_and_slide(motion)

func checkForPlayer():
	# Raycast to check if can see for player
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(position, target.position, [self], 7) # Hits environment, player, enemies
	if result:
		if result.collider.is_in_group("Player"): # Sees player and nothing inbetween
			if not result.collider.get_node("./").swappedRecently:
				return true
	return false # Failed to detect player

func rotateTowardsPlayer():
	var angleToTarget = Vector2(target.position.x - position.x, target.position.y - position.y).angle() - rotation
	if abs(angleToTarget) > PI:
		angleToTarget = angleToTarget - (sign(angleToTarget) * PI*2)
	#if rad2deg(angleToTarget) < maxRotationDiff and rad2deg(angleToTarget) > -maxRotationDiff:
	rotation += min(abs(angleToTarget), rotationSpeed) * sign(angleToTarget)


func shootBulletAtTarget(pos):
	#Shoots a bullet at the target position with some random variance
	var b = BulletType.instance()
	var a = (pos - global_position).angle()
	var dir = a + rand_range(-0.05, 0.05)
	var startPos = global_position + Vector2(bulletSpeed, 0).rotated(dir).normalized()*bulletOffset
	b.start(startPos, dir, bulletSpeed)
	b.rotationSpeed = bulletRotationSpeed
	b.maxRotationDiff =  bulletConeDegrees
	b.bulletDecayTime =  bulletDecayTime # Seconds before bullet becomes linear
	b.angleBulletUpdateDelay = angleBulletUpdateDelay
	get_parent().add_child(b)
	can_shoot = false
	waitToShoot(fire_rate)

func shootShotgunAtTarget(pos):
	#Shoots a spray of bullets at the target position with some random variance
	var spreadAngles = [-10, 0, 10]
	for i in spreadAngles:
		var b = BulletType.instance()
		var a = (pos - global_position).angle()
		var dir = a + rand_range(-0.05, 0.05)
		var startPos = global_position + Vector2(bulletSpeed, 0).rotated(dir).normalized()*bulletOffset
		b.start(startPos, a + deg2rad(i), bulletSpeed)
		get_parent().add_child(b)
	can_shoot = false
	waitToShoot(fire_rate)

func _on_Visibility_body_entered(body):
	if target:
		return
	if usesVision and body.is_in_group("Player"):
		target = body
		$Sprite.self_modulate.r = 1.0


func _on_Visibility_body_exited(body):
	if body == target:
		target = null
		$Sprite.self_modulate.r = 0.2

func waitToShoot(sec):
	timer.set_wait_time(sec) # Set Timer's delay to "sec" seconds
	timer.start() # Start the Timer counting down
	yield(timer, "timeout") # Wait for the timer to wind down
	can_shoot = true
	
func takeDamage(damage):
	hp -= damage
	if hp <= 0:
		emit_signal("enemyDeath")
		if not respawns:
			Global.destroyedObjects.append(Global.currentScene+name)
		queue_free()