"""One-shot smoke test against the running Gradio server."""
import os
import time

from gradio_client import Client

PROMPT = 'A woman speaks warmly, "Hello, how are you today?"'


def main() -> None:
    client = Client("http://127.0.0.1:7860")
    print("Submitting smoke test generation...")
    t0 = time.time()
    result = client.predict(
        PROMPT,
        None,
        2.5,
        1.5,
        1.1,
        0.0,
        10.0,
        42,
        False,
        45.0,
        37.0,
        50.0,
        api_name="/on_generate",
    )
    elapsed = time.time() - t0
    print("Result:", result)
    print("Elapsed:", round(elapsed, 1), "s")
    if result and os.path.exists(str(result)):
        print("Output file size:", os.path.getsize(str(result)), "bytes")
        print("SMOKE_TEST_OK")
    else:
        raise SystemExit("SMOKE_TEST_FAILED")


if __name__ == "__main__":
    main()
