// Reusable quiz component. Markup:
//   <div class="quiz">
//     <p class="q">Question</p>
//     <button class="opt">Option</button>              (wrong)
//     <button class="opt" data-correct>Option</button> (right)
//     <p class="fb" data-explain="Why the right answer is right."></p>
//   </div>
// Keep option text the same length, and vary which position is correct, so
// the shape of the answer gives nothing away.
document.querySelectorAll(".quiz").forEach((quiz) => {
  const opts = quiz.querySelectorAll("button.opt");
  const fb = quiz.querySelector(".fb");
  opts.forEach((btn) => {
    btn.addEventListener("click", () => {
      const ok = btn.hasAttribute("data-correct");
      btn.classList.add(ok ? "right" : "wrong");
      fb.className = "fb " + (ok ? "right" : "wrong");
      if (ok) {
        fb.textContent = "Correct. " + fb.dataset.explain;
        opts.forEach((o) => (o.disabled = true));
      } else {
        fb.textContent = "Not that one. Re-read the section above, then try again.";
        btn.disabled = true;
      }
    });
  });
});
