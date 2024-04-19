import cocotb_test
import cocotb_test.simulator

# from cocotb_test.simulator import run


def runner(top, dependencies=[], parameters=None):
    if parameters is None:
        parameters = {}



    sources = [top]
    sources.extend(dependencies)
    sources = ["hdl/" + x + ".sv" for x in sources]

    cocotb_test.simulator.run(
        verilog_sources=sources,
        toplevel=top,
        module=f"test_{top}",
        python_search=["tests/"],
        toplevel_lang="verilog",
        force_compile=True,
        verilog_compile_args = ['-g2012', '-Wall', '-Wno-sensitivity-entire-vector', '-Wno-sensitivity-entire-array', '-y./', '-y./tests', '-Y.sv', '-I./hdl', '-DSIMULATION'],
        simulator="icarus",
        parameters=parameters,
        sim_build=(f"sim_build/{top}/"
                   + "_".join((f"{i[0]}={i[1]}"
                               for i in parameters.items())))
    )