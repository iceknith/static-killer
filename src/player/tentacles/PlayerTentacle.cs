using System.Linq;
using Godot;

public partial class PlayerTentacle : Line2D
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

	[ExportGroup("Optimisation")]
	[Export]
	public int collisionCirlcleResolution { get; set; } = 10;

	[ExportGroup("Display")]
	[Export]
	public bool inverted { get; set; } = false;
	[Export]
	public bool debugDisplay { get; set; } = false;


	// Non Exported vars
	PhysicsDirectSpaceState2D spaceState2D;
	PhysicsPointQueryParameters2D pointQuery;
	PhysicsRayQueryParameters2D rayQuery;
	PhysicsShapeQueryParameters2D circleQuery;

	public Vector2[] pointsBfr;

	Vector2[] debugPoints = null;

	float preciseDebugTime = 0;
	float globalDebugTime = 0;


	// ##################
	// Base functions
	// ##################
	public override void _Ready()
	{
		//DEBUG
		///debugPoints = [];

		// Initializing default points
		pointsBfr = new Vector2[numberOfPoints];
		for (int i = 0; i < numberOfPoints; i++)
		{
			pointsBfr[i] = Vector2.Zero;
		}
		Points = pointsBfr;

		// Initializing Width Curve
		if (inverted)
		{
			inverted = false; // Reset the invertion so that the Invert() method does its job correctly
			Invert();
		}
		else
		{
			SendWidthCurveToShader();
		}

		// Initializing point & ray Querries
		pointQuery = new PhysicsPointQueryParameters2D();
		rayQuery = new PhysicsRayQueryParameters2D();
		circleQuery = new PhysicsShapeQueryParameters2D();
		circleQuery.Shape = new CircleShape2D();
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

			if (debugPoints != null)
			{
				for (int i = 0; i < debugPoints.Length - 1; i++)
				{
					if (debugPoints[i + 1] == Vector2.Zero || debugPoints[i] == Vector2.Zero) continue;

					DrawLine(debugPoints[i], debugPoints[i + 1], Colors.White);
				}
			}
		}
	}

	public override void _Process(double delta)
	{
		base._Process(delta);

		calculateAndStoreNormals();
	}


	// ##################
	// Regression (FABRIK with collisions) functions
	// ##################

	public void FabrikChainForwards(Vector2 goalPoint, bool goalPointSafe)
	{
		// Initialize variables
		spaceState2D = GetWorld2D().DirectSpaceState;
		Vector2 pointNewPos;
		int lastIndx = Points.Length - 1;

		// Move First Point
		if (goalPointSafe) pointsBfr[lastIndx] = goalPoint;
		else pointsBfr[lastIndx] = MovementWithCollisions(pointsBfr[lastIndx], goalPoint);

		// Move Other Points
		for (int i = lastIndx - 1; i >= 0; i--)
		{
			pointNewPos = ConstraintDistace(pointsBfr[i], pointsBfr[i + 1], maxDistance);
			pointsBfr[i] = pointNewPos;
		}
	}

	public void FabrikChainBackwards(Vector2 anchorPosition, float leadway)
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
		pointNewPos = ConstraintDistace(pointsBfr[lastIndx], pointsBfr[lastIndx - 1], maxDistance + leadway);
		pointsBfr[lastIndx] = ChainMovementWithCollisions(pointsBfr[lastIndx], pointNewPos, pointsBfr[lastIndx - 1], maxDistance + leadway);

	}

	public static Vector2 ConstraintDistace(Vector2 point, Vector2 anchor, float dist)
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

		Godot.Collections.Array<Godot.Collections.Dictionary> pointResult = spaceState2D.IntersectPoint(pointQuery);
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
			Godot.Collections.Dictionary rayResult;
			rayQuery.CollisionMask = uint.MaxValue;

			// Define the positions
			Vector2 anchorGlobalPos = anchorPos + GlobalPosition;
			float offset = Mathf.Pi / collisionCirlcleResolution;
			Vector2 pos1 = Vector2.Inf;
			Vector2 pos2 = Vector2.Inf;

			// Define original angle
			float initAngle = (anchorPos - goalPos).Angle() + Mathf.Pi;

			// Define the point test distance
			float marginDistance = 1f;

			//DEBUG CIRCLE DRAW
			//debugPoints = new Vector2[2 * collisionCirlcleResolution + 1];
			//debugPoints[0] = anchorGlobalPos + Vector2.FromAngle(initAngle) * dist;
			//int i = 1;

			// Positive way iteration
			for (float angle = initAngle; angle <= initAngle + Mathf.Pi; angle += offset)
			{
				rayQuery.To = anchorGlobalPos + Vector2.FromAngle(angle) * dist;
				rayQuery.From = anchorGlobalPos + Vector2.FromAngle(angle + offset) * dist;

				//DEBUG CIRCLE DRAW
				//debugPoints[i] = rayQuery.To;
				//i++;

				rayResult = spaceState2D.IntersectRay(rayQuery);
				if (rayResult.Count != 0)
				{
					pos1 = (Vector2)rayResult["position"];

					// Check if the result is valid
					pointQuery.Position = pos1 + (Vector2)rayResult["normal"] * marginDistance;
					pointResult = spaceState2D.IntersectPoint(pointQuery);
					if (pointResult.Count != 0)
					{
						// Not valid
						pos1 = Vector2.Inf;
					}
					else
					{
						break;
					}
				}
			}

			//DEBUG CIRCLE DRAW
			//i = 2 * collisionCirlcleResolution;

			// Negative way iteration
			for (float angle = initAngle; angle >= initAngle - Mathf.Pi; angle -= offset)
			{
				rayQuery.To = anchorGlobalPos + Vector2.FromAngle(angle) * dist;
				rayQuery.From = anchorGlobalPos + Vector2.FromAngle(angle - offset) * dist;

				//DEBUG CIRCLE DRAW
				//debugPoints[i] = rayQuery.From;
				//i--;

				rayResult = spaceState2D.IntersectRay(rayQuery);
				if (rayResult.Count != 0)
				{
					pos2 = (Vector2)rayResult["position"];

					// Check if the result is valid
					pointQuery.Position = pos2 + (Vector2)rayResult["normal"] * marginDistance;
					pointResult = spaceState2D.IntersectPoint(pointQuery);
					if (pointResult.Count != 0)
					{
						// Not valid
						pos2 = Vector2.Inf;
					}
					else
					{
						break;
					}
				}
			}

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

	public void ApplyBufferedMovements()
	{
		Points = pointsBfr;
	}

	// ##################
	// Display functions
	// ##################

	private void calculateAndStoreNormals()
	{
		Color vectToColor(Vector2 vect)
		{
			// Transforms a vect to its normal: n
			// And calculates its color, using this formula:
			// R : (n.x + 1)/2 ; G : (n.y + 1)/2 ; B : 0 ; A : 0
			return new Color((-vect.Y + 1) / 2, (vect.X + 1) / 2, 0, 1);
		}

		// Initializing gradient
		Gradient = new Gradient();

		// Define variables
		int pointsSize = Points.Length;
		Vector2 tangent;

		// First point
		tangent = (Points[1] - Points[0]).Normalized();
		Gradient.AddPoint(0, vectToColor(tangent));

		// Other points
		for (int i = 1; i < pointsSize - 1; i++)
		{
			tangent = (Points[i + 1] - Points[i - 1]).Normalized();
			Gradient.AddPoint((float)i / (pointsSize - 1), vectToColor(tangent));
		}

		// Last point
		tangent = (Points[pointsSize - 1] - Points[pointsSize - 2]).Normalized();
		Gradient.AddPoint(1, vectToColor(tangent));
	}

	public void Invert()
	{
		// Inverting all points
		for (int i = 0; i < numberOfPoints; i++)
		{
			pointsBfr[numberOfPoints - i - 1] = Points[i];
		}
		Points = pointsBfr;

		// Inverting all points from width curve
		inverted = !inverted;
		Vector2[] newPoints = new Vector2[WidthCurve.PointCount];
		for (int i = 0; i < WidthCurve.PointCount; i++)
		{
			Vector2 newPos = WidthCurve.GetPointPosition(i);
			newPos.X = WidthCurve.MaxDomain - newPos.X;
			newPoints[i] = newPos;
		}

		// Clearing all points from width curve
		WidthCurve.ClearPoints();

		foreach (Vector2 point in newPoints)
		{
			WidthCurve.AddPoint(point);
		}

		SendWidthCurveToShader();
		(Material as ShaderMaterial).SetShaderParameter("inverted", inverted);
	}

	private void SendWidthCurveToShader()
	{
		CurveTexture widthCurveTexture = new CurveTexture();
		widthCurveTexture.Curve = WidthCurve;
		(Material as ShaderMaterial).SetShaderParameter("curve_texture", widthCurveTexture);
	}


}
