import random

from matensemble.chore import ChoreSpec
from matensemble.model import Resources
from matensemble.pipeline import Pipeline

pipe = Pipeline()

LOW, HIGH = 1, 100
ANSWER = random.randint(LOW, HIGH)


@pipe.chore()
def guess(lower: int, upper: int, attempt: int = 1) -> dict:
    """Guess the midpoint of the current range."""
    return {
        "guess": (lower + upper) // 2,
        "low": lower,
        "high": upper,
        "attempt": attempt,
    }


# The BOLO_list is a list of chores that you are telling the manager to
# Be On the Look-Out for. If one of these chores completes then the manager
# will see it and say "HEY! You're a wanted criminal" and spawn your strategy
# passing the results of the completed chore that was in the BOLO list to the
# strategy as an argument. You can have multiple chores in this list.
@pipe.strategy(bolo_list=["guess"])
def higher_or_lower(result):
    """Narrow the range and schedule the next guess."""
    current = result["guess"]

    if current == ANSWER:
        print(f"Got {ANSWER} in {result['attempt']} guesses!")
        return None

    low, high = result["low"], result["high"]

    if current < ANSWER:
        low = current + 1
    else:
        high = current - 1

    return ChoreSpec(
        args=(low, high, result["attempt"] + 1),
        kwargs={},
        resources=Resources(),
        qualname="guess",
    )


# Seed the workflow
guess(LOW, HIGH)

# Run until no more chores remain
print(pipe.submit(log_delay=1).result())
