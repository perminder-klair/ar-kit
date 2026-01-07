The Core Problem

  We have two independent coordinate systems:
  - Room scan (RoomPlan): Creates USDZ in coordinate system A
  - Depth capture (ARSession): Captures damage in coordinate system B

  No shared reference point between them.

  Possible Solutions

  Let me analyze each approach:

  Option 1: Camera Direction + Wall Matching (Best practical option)

  Concept: Use the camera's facing direction during depth capture to determine which wall was being viewed, then use the bounding box position (0-1 normalized) to place the marker proportionally on that wall.

  How it works:
  1. Get camera forward direction from frame.cameraTransform
  2. Compare with each wall's normal vector (from CapturedRoom)
  3. Find best matching wall (highest dot product)
  4. Map bounding box center (x: 0.3, y: 0.5) → position on wall (30% from left, 50% from top)
  5. Transform local wall position to world coordinates

  Accuracy: ~70-80% if camera faced wall directly
  Complexity: Medium
  Limitation: Accuracy degrades if user photographed at an angle

  ---
  Option 2: Visual Markers for Coordinate Alignment (Most accurate)

  Concept: Use physical markers (QR codes, ArUco markers) placed in the room to compute a transformation matrix between coordinate systems.

  How it works:
  1. During room scan: Detect marker positions in RoomPlan's coordinate system
  2. During depth capture: Detect same markers in ARSession's coordinate system
  3. Compute transformation matrix between the two
  4. Apply transform to all damage positions

  Accuracy: >95%
  Complexity: High
  Limitation: Requires user to place/print markers before scanning

  ---
  Option 3: Damage Detection DURING Room Scan (Different workflow)

  Concept: Instead of separate depth capture, analyze frames in real-time during the room scan itself.

  How it works:
  1. During RoomCaptureSession, capture periodic screenshots
  2. Run Gemini analysis on frames (async)
  3. Associate detected damage with currently visible surfaces
  4. Both share the same coordinate system (no mismatch!)

  Accuracy: High (same coordinate system)
  Complexity: Medium-High
  Limitation: No depth data in RoomCaptureView screenshots, slower UX

  ---
  Option 4: ARWorldMap Persistence (Theoretical)

  Concept: Save ARKit's world map from room scan, load it in depth capture session.

  Problem: RoomCaptureSession doesn't expose its underlying ARSession or world map. Apple API limitation.

  Accuracy: Would be ~95%
  Status: Not possible with current RoomPlan API

  ---
  Option 5: Texture/UV Projection

  Concept: Project damage as a texture overlay onto the mesh instead of 3D markers.

  Problem: RoomPlan's USDZ export doesn't include detailed UV mapping for walls.

  Status: Not practical with current exports
