# hdl-notebook
A set of random VHDL entities that may become useful at some point to somebody.

The code in this repository may be incomplete, or blatantly wrong.

It is there mostly just to serve as an idea notebook for later use, or for possible code re-use.

## Project structure

- `/components` 
    - contains sources and documentation for all components
    - `/${component-name}`
        - contains sources and documentation for this particular component
            - `/src`
                - contains sources for this component
                - `${component-name}.vhd`
                    - VHDL entity representing this component
            - `/doc`
                - contains documentation resources for this component
            - `README.md`
                - basic information about this particular component

## Things that are notably missing

- Tests. All and any sorts of tests.
    - It's probably smart to look into this someday.
    - All the basic testbenches!
    - GHDL + PSL stuff? OSVVM stuff? Research all the things!
        - One might even be able to run the tests inside of GitHub Actions and generate a cute test badge (maybe) 