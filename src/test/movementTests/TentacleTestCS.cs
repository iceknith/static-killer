using System;
using System.ComponentModel.DataAnnotations;
using System.Drawing;
using System.Linq;
using Godot;
using Godot.NativeInterop;
using Microsoft.VisualBasic;

public partial class TentacleTestCS : Line2D
{
	// ##################
	// Defining variables
	// ##################

	// Signals
	[Signal]
	public delegate void MovementEventHandler(float movement, int iterations);

	// Exported vars
	[ExportGroup("Tentacle definition")]
	[Export]
	public float maxDistance { get; set; } = 6f;
	[Export]
	public int numberOfPoints { get; set; } = 50;
	[Export]
	public Vector2 anchorPosition { get; set; }

	[ExportGroup("Speed")]
	[Export]
	public float maxSpeed { get; set; } = 200f;
	[Export]
	public float acceleration { get; set; } = 30f;

	[ExportGroup("Optimisation")]
	[Export]
	public int collisionCirlcleResolution { get; set; } = 10;
	[Export]
	public int regressionMaxIterations { get; set; } = 4;
	[Export]
	public float regressionErrorDistSqr { get; set; } = 0.01f;
	[Export]
	public float regressionConvergenceDistSqr { get; set; } = 0.0001f;

	[ExportGroup("Display")]
	[Export]
	public bool inverted { get; set; } = false;
	[Export]
	public bool debugDisplay { get; set; } = false;


	// Non Exported vars
	Vector2[] pointsBfr;
	public Vector2 goalPoint;
	public float speed;
	PhysicsDirectSpaceState2D spaceState2D;
	PhysicsPointQueryParameters2D pointQuery;
	PhysicsRayQueryParameters2D rayQuery;

	Vector2[] debugPoints;

	float preciseDebugTime = 0;
	float globalDebugTime = 0;


	// ##################
	// Base functions
	// ##################
	public override void _Ready()
	{
		//DEBUG
		debugPoints = [];

		// Initializing GoalPoint
		goalPoint = anchorPosition;

		// Initializing default points
		pointsBfr = new Vector2[numberOfPoints];
		for (int i = 0; i < numberOfPoints; i++)
		{
			pointsBfr[i] = anchorPosition;
		}
		Points = pointsBfr;

		// Initializing Width Curve
		if (inverted)
		{
			Invert();
			inverted = true;
		}
		else
		{
			SendWidthCurveToShader();
		}

		// Initializing point & ray Querries
		pointQuery = new PhysicsPointQueryParameters2D();
		rayQuery = new PhysicsRayQueryParameters2D();
	}


	public override void _Draw()
	{
		base._Draw();

		if (debugDisplay)
		{
			for (int i = 0; i < numberOfPoints; i++)
			{
				Vector2 point = Points[i];
				DrawCircle(point, maxDistance / 7, Colors.RebeccaPurple);
				//DrawCircle(point, maxDistance, Colors.Azure, false);
			}

			DrawCircle(goalPoint, 3, Colors.Red);

			for (int i = 0; i < debugPoints.Length-1; i++)
			{
				if (debugPoints[i + 1] == Vector2.Zero || debugPoints[i] == Vector2.Zero) continue;

				DrawLine(debugPoints[i], debugPoints[i + 1], Colors.White);
			}
		}
	}

	public override void _Process(double delta)
	{
		base._Process(delta);

		calculateAndStoreNormals();
	}

	public override void _PhysicsProcess(double delta)
	{
		float start = Time.GetTicksUsec();

		Vector2 movement = new Vector2(Input.GetAxis("left1", "right1"), Input.GetAxis("up1", "down1"));
		if (movement == Vector2.Zero) return;

		int lastIndx = Points.Length - 1;
		Vector2 oldPos = Points[lastIndx];
		speed = maxSpeed * (float)delta;
		goalPoint = oldPos + movement.Normalized() * speed;
		//goalPoint = GetViewport().GetMousePosition();

		//Debug
		preciseDebugTime = 0;


		pointsBfr = Points;

		int i;
		for (i = 0; i < regressionMaxIterations; i++)
		{
			// If it doesn't converge in second try, then use the tangent to make it convert
			if (i == 2)
			{
				Vector2 relativeMovement = (pointsBfr[lastIndx] - oldPos).Normalized();
				goalPoint = oldPos + relativeMovement * speed;
			}

			Vector2 lastPos = pointsBfr[lastIndx];
			FabrikChainForwards();
			FabrikChainBackwards();

			if (goalPoint.DistanceSquaredTo(pointsBfr[lastIndx]) <= regressionErrorDistSqr ||
			lastPos.DistanceSquaredTo(pointsBfr[lastIndx]) <= regressionConvergenceDistSqr)
			{
				break;
			}
		}

		Points = pointsBfr;

		EmitSignal(SignalName.Movement, oldPos.DistanceTo(Points[lastIndx]), i);

		float end = Time.GetTicksUsec();

		globalDebugTime = end - start;

		//GD.Print(preciseDebugTime / 1000, "ms precise | ", globalDebugTime / 1000, "ms global |  ", 100 * preciseDebugTime / globalDebugTime, "%");
	}

	// ##################
	// Regression (FABRIK with collisions) functions
	// ##################

	public void FabrikChainForwards()
	{
		// Initialize variables
		spaceState2D = GetWorld2D().DirectSpaceState;
		Vector2 pointNewPos;
		int lastIndx = pointsBfr.Length - 1;

		// Move First Point
		pointsBfr[lastIndx] = goalPoint;

		// Move Other Points
		for (int i = lastIndx - 1; i >= 0; i--)
		{
			pointNewPos = ConstraintDistace(pointsBfr[i], pointsBfr[i + 1], maxDistance);
			pointsBfr[i] = pointNewPos;
		}
	}

	public void FabrikChainBackwards()
	{
		// Move first point (anchor point)
		pointsBfr[0] = anchorPosition;
		
		// Initialize recurring variables
		int lastIndx = pointsBfr.Length - 1;
		Vector2 pointNewPos;

		// Move other points
		for (int i = 1; i < lastIndx; i++)
		{
			pointNewPos = ConstraintDistace(pointsBfr[i], pointsBfr[i - 1], maxDistance);
			pointsBfr[i] = ChainMovementWithCollisions(pointsBfr[i], pointNewPos, pointsBfr[i - 1], maxDistance);
		}

		// Treating last indx to artificially put him at the desired position
		pointNewPos = ConstraintDistace(pointsBfr[lastIndx], pointsBfr[lastIndx - 1], maxDistance + 5*speed);
		pointsBfr[lastIndx] = ChainMovementWithCollisions(pointsBfr[lastIndx], pointNewPos, pointsBfr[lastIndx - 1], maxDistance + 5*speed);

	}

	public Vector2 ConstraintDistace(Vector2 point, Vector2 anchor, float dist)
	{
		float pointDist = point.DistanceTo(anchor);
		if (pointDist < dist)
		{
			return anchor + (point - anchor).Normalized() * pointDist;
		}
		else
		{
			return anchor + (point - anchor).Normalized() * dist;
		}
	}

	public Vector2 MovementWithCollisions(Vector2 initPos, Vector2 goalPos)
	{
		// Initialize variables
		Vector2 initGlobalPos = initPos + GlobalPosition;
		rayQuery.From = initGlobalPos;
		rayQuery.To = goalPos + GlobalPosition;

		Godot.Collections.Dictionary result = spaceState2D.IntersectRay(rayQuery);
		if (result.Count == 0)
		{
			return goalPos;
		}
		else
		{
			// Collision detected, we adjust the movement
			Vector2 collisionPoint = (Vector2)result["position"];
			Vector2 collisionNormal = (Vector2)result["normal"];

			if (collisionNormal == Vector2.Zero)
			{
				return goalPos;
			}

			// Find the projected movement to slide along the obstacle
			Vector2 slideMovement = (goalPos - initPos).Slide(collisionNormal);

			// Verify if we can moove after having adjust the trajectory
			rayQuery.From = initGlobalPos;
			rayQuery.To = initGlobalPos + slideMovement;
			result = spaceState2D.IntersectRay(rayQuery);

			if (result.Count == 0)
			{
				// If we can do this movement, do it
				return initPos + slideMovement;
			}

			// Else, don't move
			return initPos;
		}
	}

	public Vector2 ChainMovementWithCollisions(Vector2 initPos, Vector2 goalPos, Vector2 anchorPos, float dist)
	{
		// Define variables
		pointQuery.CollisionMask = uint.MaxValue;
		pointQuery.Position = goalPos + GlobalPosition;

		float start = Time.GetTicksUsec();
		Godot.Collections.Array<Godot.Collections.Dictionary> pointResult = spaceState2D.IntersectPoint(pointQuery);
		float end = Time.GetTicksUsec();
		preciseDebugTime += end - start;
		if (pointResult.Count == 0)
		{
			return goalPos;
		}
		else
		{
			// Collision detected, find the intersection between the circle and the rest

			// Ligne théoriquement intéressante, à décommenter quand le reste du code fonctionnera
			dist = Mathf.Min(dist, anchorPos.DistanceTo(goalPos));

			// Define the raycast
			//rayQuery.HitFromInside = false;
			Godot.Collections.Dictionary rayResult;
			rayQuery.CollisionMask = uint.MaxValue;

			// Define the positions
			Vector2 anchorGlobalPos = anchorPos + GlobalPosition;
			float offset = Mathf.Pi / collisionCirlcleResolution;
			Vector2 pos1 = Vector2.Inf;
			Vector2 pos2 = Vector2.Inf;

			// Define original angle
			float initAngle = (anchorPos - goalPos).Angle() + Mathf.Pi;

			//DEBUG
			debugPoints = new Vector2[2 * collisionCirlcleResolution + 1];
			debugPoints[0] = anchorGlobalPos + Vector2.FromAngle(initAngle) * dist;
			int i = 1;

			// Positive way iteration
			for (float angle = initAngle; angle <= initAngle + Mathf.Pi; angle += offset)
			{
				rayQuery.To = anchorGlobalPos + Vector2.FromAngle(angle) * dist;
				rayQuery.From = anchorGlobalPos + Vector2.FromAngle(angle + offset) * dist;

				//DEBUG
				debugPoints[i] = rayQuery.To;
				i++;

				rayResult = spaceState2D.IntersectRay(rayQuery);
				if (rayResult.Count != 0)
				{
					pos1 = (Vector2)rayResult["position"];
					break;
				}
			}

			//DEBUG
			i = 2 * collisionCirlcleResolution;

			// Negative way iteration
			for (float angle = initAngle; angle >= initAngle - Mathf.Pi; angle -= offset)
			{
				rayQuery.To = anchorGlobalPos + Vector2.FromAngle(angle) * dist;
				rayQuery.From = anchorGlobalPos + Vector2.FromAngle(angle - offset) * dist;

				//DEBUG
				debugPoints[i] = rayQuery.From;
				i--;

				rayResult = spaceState2D.IntersectRay(rayQuery);
				if (rayResult.Count != 0)
				{
					pos2 = (Vector2)rayResult["position"];
					break;
				}
			}

			// DebugTime
			//float end = Time.GetTicksUsec();
			//preciseDebugTime += end - start;

			pos1 -= GlobalPosition;
			pos2 -= GlobalPosition;
			if (pos2 != Vector2.Inf && goalPos.DistanceSquaredTo(pos1) >= goalPos.DistanceSquaredTo(pos2))
			{
				return pos2;
			}
			else if (pos1 != Vector2.Inf)
			{
				return pos1;
			}
			else
			{
				return initPos;
			}

		}
	}

	// ##################
	// Display functions
	// ##################

	private void calculateAndStoreNormals()
	{
		Godot.Color vectToColor(Vector2 vect)
		{
			// Transforms a vect to its normal: n
			// And calculates its color, using this formula:
			// R : (n.x + 1)/2 ; G : (n.y + 1)/2 ; B : 0 ; A : 0
			return new Godot.Color((-vect.Y + 1) / 2, (vect.X + 1) / 2, 0, 1);
		}

		// Define variables
		Gradient gradient = new Gradient();
		int pointsSize = Points.Length;
		Vector2 tangent;

		// First point
		tangent = Points[1] - Points[0];
		gradient.AddPoint(0, vectToColor(tangent));

		// Other points
		for (int i = 1; i < pointsSize - 1; i++)
		{
			tangent = Points[i + 1] - Points[i - 1];
			gradient.AddPoint(i/(pointsSize-1), vectToColor(tangent));
		}

		// Last point
		tangent = Points[pointsSize - 1] - Points[pointsSize - 2];
		gradient.AddPoint(1, vectToColor(tangent));
	}

	private void Invert()
	{
		// Inverting all points from width curve
		inverted = !inverted;
		Vector2[] newPoints = [];
		for (int i = 0; i < WidthCurve.PointCount; i++)
		{
			Vector2 newPos = WidthCurve.GetPointPosition(i);
			newPos.X = WidthCurve.MaxDomain - newPos.X;
			newPoints.Append(newPos);
		}

		// Clearing all points from width curve
		WidthCurve.ClearPoints();

		foreach (Vector2 point in newPoints)
		{
			WidthCurve.AddPoint(point);
		}

		SendWidthCurveToShader();
	}

	private void SendWidthCurveToShader()
	{
		CurveTexture widthCurveTexture = new CurveTexture();
		widthCurveTexture.Curve = WidthCurve;
		(Material as ShaderMaterial).SetShaderParameter("curve_texture", widthCurveTexture);
	}


}
