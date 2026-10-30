"""Query the deployed Easy English schema in an isolated native Rime session.

Usage: python tools/test-easy-en.py --rime-dir "C:/Program Files/Rime/weasel-0.17.4"
Requires an existing build/ from Weasel deployment; no Python packages required.
"""

import argparse
import ctypes as C
import pathlib
import shutil
import tempfile


class Traits(C.Structure):
    _fields_ = [
        ("data_size", C.c_int), ("shared_data_dir", C.c_char_p),
        ("user_data_dir", C.c_char_p), ("distribution_name", C.c_char_p),
        ("distribution_code_name", C.c_char_p), ("distribution_version", C.c_char_p),
        ("app_name", C.c_char_p), ("modules", C.POINTER(C.c_char_p)),
        ("min_log_level", C.c_int), ("log_dir", C.c_char_p),
        ("prebuilt_data_dir", C.c_char_p), ("staging_dir", C.c_char_p),
    ]


class Composition(C.Structure):
    _fields_ = [("length", C.c_int), ("cursor_pos", C.c_int),
                ("sel_start", C.c_int), ("sel_end", C.c_int), ("preedit", C.c_char_p)]


class Candidate(C.Structure):
    _fields_ = [("text", C.c_char_p), ("comment", C.c_char_p), ("reserved", C.c_void_p)]


class Menu(C.Structure):
    _fields_ = [("page_size", C.c_int), ("page_no", C.c_int),
                ("is_last_page", C.c_int), ("highlighted_candidate_index", C.c_int),
                ("num_candidates", C.c_int), ("candidates", C.POINTER(Candidate)),
                ("select_keys", C.c_char_p)]


class Context(C.Structure):
    _fields_ = [("data_size", C.c_int), ("composition", Composition), ("menu", Menu),
                ("commit_text_preview", C.c_char_p), ("select_labels", C.POINTER(C.c_char_p))]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rime-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    build = root / "build"
    for name in ("easy_en.schema.yaml", "easy_en.table.bin", "easy_en.prism.bin"):
        if not (build / name).is_file():
            parser.error(f"Missing build/{name}; deploy with Weasel first")
    rime = C.CDLL(str(args.rime_dir.resolve() / "rime.dll"))

    def bind(name, arguments, result):
        function = getattr(rime, name)
        function.argtypes = arguments
        function.restype = result
        return function

    setup = bind("RimeSetup", [C.POINTER(Traits)], None)
    initialize = bind("RimeInitialize", [C.POINTER(Traits)], None)
    create = bind("RimeCreateSession", [], C.c_size_t)
    select = bind("RimeSelectSchema", [C.c_size_t, C.c_char_p], C.c_int)
    simulate = bind("RimeSimulateKeySequence", [C.c_size_t, C.c_char_p], C.c_int)
    get_context = bind("RimeGetContext", [C.c_size_t, C.POINTER(Context)], C.c_int)
    free_context = bind("RimeFreeContext", [C.POINTER(Context)], C.c_int)
    clear = bind("RimeClearComposition", [C.c_size_t], None)
    finalize = bind("RimeFinalize", [], None)

    # Only the freshly created child of build/ is removed during cleanup.
    sandbox = pathlib.Path(tempfile.mkdtemp(prefix="easy-en-test-", dir=build)).resolve()
    if sandbox.parent != build.resolve():
        raise RuntimeError("Test directory is outside build/")
    try:
        (sandbox / "build").mkdir()
        (sandbox / "lua").mkdir()
        for source in build.glob("easy_en.*"):
            shutil.copy2(source, sandbox / "build" / source.name)
        for source in (root / "lua").glob("easy_en*"):
            shutil.copy2(source, sandbox / "lua" / source.name)
        (sandbox / "build" / "default.yaml").write_text(
            "schema_list:\n  - schema: easy_en\nascii_composer:\n"
            "  switch_key:\n    Shift_L: commit_code\n", encoding="utf-8")
        traits = Traits()
        traits.data_size = C.sizeof(Traits) - C.sizeof(C.c_int)
        traits.shared_data_dir = str(args.rime_dir.resolve() / "data").encode()
        traits.user_data_dir = str(sandbox).encode()
        traits.app_name = b"rime.easy_en_test"
        # Glog keeps file handles until process exit, even after RimeFinalize.
        traits.log_dir = b""
        traits.min_log_level = 2
        setup(C.byref(traits))
        initialize(C.byref(traits))
        try:
            session = create()
            if not session or not select(session, b"easy_en"):
                raise RuntimeError("Could not select Easy English")
            failures = []
            cases = {"ive": "I've ", "im": "I'm ", "dont": "don't ",
                     "cant": "can't ", "its": "its ", "hello": "hello "}
            for word, expected in cases.items():
                clear(session)
                if not simulate(session, word.encode()):
                    raise RuntimeError(f"Input was rejected: {word}")
                context = Context()
                context.data_size = C.sizeof(Context) - C.sizeof(C.c_int)
                if not get_context(session, C.byref(context)):
                    raise RuntimeError(f"No context for {word}")
                try:
                    candidates = [context.menu.candidates[i].text.decode()
                                  for i in range(context.menu.num_candidates)]
                finally:
                    free_context(C.byref(context))
                print(f"{word}: {candidates}")
                if not candidates or candidates[0] != expected:
                    failures.append(f"{word}: expected first candidate {expected!r}")
            if failures:
                raise AssertionError("\n".join(failures))
            print(f"PASS: {len(cases)} native Rime candidate checks")
        finally:
            finalize()
    finally:
        shutil.rmtree(sandbox)


if __name__ == "__main__":
    main()
