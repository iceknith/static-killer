using Godot;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;

public partial class Player : Area2D
{

	// ##################
	// Defining variables
	// ##################

	[Export]
	public string playerNumber = "1";


	[ExportGroup("Speed")]
	[Export]
	public float maxSpeed { get; set; } = 200f;
	[Export]
	public float acceleration { get; set; } = 30f;

	[ExportGroup("Misc")]
	[Export]
	public float tentaclesDist { get; set; } = 5f;

	[ExportGroup("Optimisation")]
	[Export]
	public int regressionMaxIterations { get; set; } = 4;
	[Export]
	public float regressionErrorDistSqr { get; set; } = 0.01f;
	[Export]
	public float regressionConvergenceDistSqr { get; set; } = 0.01f;

	// Tentacles variables
	private PlayerTentacle headTentacle, tailTentacle;
	private int headLength, tailLength;
	bool firstTentacleHead = true;

	// Player Variables
	private CollisionShape2D collisionShape;
	private Sprite2D sprite;
	float currentSpeed;

	// Movement variables
	public Vector2 anchorPos;

	// Input variables
	Dictionary<string, string> inputMap = new Dictionary<string, string>
	{
		{"left", "" },
		{"right", ""},
		{"up", ""},
		{"down", ""},
		{"grab", ""}
	};


	// ##################
	// Godot Method Overrides
	// ##################

	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		// Define tentacle variables
		headTentacle = (PlayerTentacle)GetNode("Tentacle1");
		tailTentacle = (PlayerTentacle)GetNode("Tentacle2");
		headLength = headTentacle.numberOfPoints;
		tailLength = headTentacle.numberOfPoints;

		tailTentacle.Invert();

		// Define player variables
		collisionShape = (CollisionShape2D)GetNode("CollisionShape2D");
		sprite = (Sprite2D)GetNode("Sprite2D");

		// TEMP
		anchorPos = Vector2.Zero;

		// Input variables
		foreach (string key in inputMap.Keys)
		{
			inputMap[key] = key + playerNumber;
		}
	}


	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		// Change hands
		if (Input.IsActionJustPressed(inputMap["grab"]))
		{
			firstTentacleHead = !firstTentacleHead;
			anchorPos = headTentacle.Points[headLength - 1];

			// Switch tentacles
			PlayerTentacle tempTentacle = headTentacle;
			headTentacle = tailTentacle;
			tailTentacle = tempTentacle;

			// Invert both tentacles
			headTentacle.Invert();
			tailTentacle.Invert();
		}
	}

	public override void _PhysicsProcess(double delta)
	{

		Vector2 movement = new Vector2(Input.GetAxis(inputMap["left"], inputMap["right"]), Input.GetAxis(inputMap["up"], inputMap["down"])).Normalized();
		if (movement == Vector2.Zero) return;

		GroundedMovementHandler(movement, delta);
	}



	// ##################
	// Movement Methods
	// ##################

	private void GroundedMovementHandler(Vector2 movement, double delta)
	{
		Vector2 oldPos = headTentacle.pointsBfr[headLength - 1];
		currentSpeed = maxSpeed * (float)delta;
		Vector2 goalPoint = oldPos + movement * currentSpeed;

		int i;
		for (i = 0; i < regressionMaxIterations; i++)
		{
			Vector2 lastPos = headTentacle.pointsBfr[headLength - 1];

			// If it doesn't converge in second try, then use the tangent to make it convert
			if (i == 2)
			{
				Vector2 relativeMovement = (lastPos - oldPos).Normalized();
				goalPoint = oldPos + relativeMovement * currentSpeed;
			}

			FABRIKChainMovement(goalPoint);
			Vector2 currentPos = headTentacle.pointsBfr[headLength - 1];

			// Convergence check
			if (goalPoint.DistanceSquaredTo(currentPos) <= regressionErrorDistSqr ||
				lastPos.DistanceSquaredTo(currentPos) <= regressionConvergenceDistSqr)
			{
				break;
			}
		}

		// Move sprite & collision box
		Vector2 headFirstPoint = headTentacle.pointsBfr[0];
		Vector2 tailLastPoint = tailTentacle.pointsBfr[tailLength - 1];

		Vector2 headPos = (headFirstPoint + tailLastPoint) / 2;
		float headAngle = tailLastPoint.AngleToPoint(headFirstPoint);
		if (firstTentacleHead) headAngle += Mathf.Pi;

		sprite.Position = headPos;
		sprite.Rotation = headAngle;

		collisionShape.Position = headPos;
		collisionShape.Rotation = headAngle;

		// Affect the changes
		headTentacle.ApplyBufferedMovements();
		tailTentacle.ApplyBufferedMovements();
	}

	private void FABRIKChainMovement(Vector2 goalPoint)
	{
		// Forwards
		headTentacle.FabrikChainForwards(goalPoint, false);
		Vector2 tailGoalPoint = PlayerTentacle.ConstraintDistace(tailTentacle.pointsBfr[tailLength - 1], headTentacle.pointsBfr[0], tentaclesDist);
		tailTentacle.FabrikChainForwards(tailGoalPoint, true);

		// Backwards
		tailTentacle.FabrikChainBackwards(anchorPos, 0);
		Vector2 tailTentacleEnd = tailTentacle.pointsBfr[tailLength - 1];
		Vector2 headTentacleStart = headTentacle.pointsBfr[0];

		Vector2 headAnchorGoalPos = PlayerTentacle.ConstraintDistace(headTentacleStart, tailTentacleEnd, tentaclesDist);
		Vector2 headAnchorPos = headTentacle.ChainMovementWithCollisions(headTentacleStart, headAnchorGoalPos, tailTentacleEnd, tentaclesDist);
		headTentacle.FabrikChainBackwards(headAnchorPos, 5 * currentSpeed); // currentSpeed * 5 : magic number, aimed to be fixed
	}

	// ##################
	// Action Handlers
	// ##################



}
