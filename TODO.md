# TODO List

## Research Stage

- [x]  Revisit Fluid Mechanics notes from university
- [x]  Revisit CFD notes from university
- [x]  Revisit Numeric Analysis notes from university
- [x]  Research how mesh files are constructed and the most popular FOSS formats (.msh)
- [x]  Research popular visualization tools (paraview using VTK)
- [x]  Research how to store the simulation results (VTK + CSV)
- [x]  Choose an initial solver to implement
- [x]  Do the ziglings.org exercises

## Development Stage

### Get it working in 2D

- [ ] Implement 2D mesh file parser
- [ ] Implement simple 2D solver (lid cavity is hello world of CFD code)
- [ ] Solve simplest case and be able to visualize it on paraview
- [ ] Implement some more complex 2D solvers (turbulent flow)

### Get it working on 3D

- [ ] Expand mesh file parser to 3D meshes
- [ ] Implement 3D solvers

### Development Notes

- [ ] Try to stick with data oriented design
- [ ] Study possibility of including RAND-NLA
- [ ] Study possibility of using VULKAN for paralellism
