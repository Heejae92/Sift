# Sift

Clean up old screenshots with a simple swipe.

**[Try the simulator](https://heejae92.github.io/Sift/simulator.html)** · [View code on GitHub](https://github.com/Heejae92/Sift)

<p align="center">
  <img src="docs/screenshots/1-onboarding.png" width="160" alt="Welcome screen: swipe left to Trash, right to Archive, up to Fave, and a Get started button">
  <img src="docs/screenshots/2-review.png" width="160" alt="Review screen: a Settings screenshot as a card, with Rewind, Trash, Fave and Archive buttons">
  <img src="docs/screenshots/3-all-done.png" width="160" alt="All-done screen: Inbox zero, screenshot edition, with an Open Trash button">
  <img src="docs/screenshots/4-trash.png" width="160" alt="Trash screen: seven screenshots in a grid above a Delete all button">
  <img src="docs/screenshots/5-library.png" width="160" alt="Library screen: the Archive tab with eight archived screenshots">
</p>

## The problem

I take a lot of screenshots: tickets, recipes, maps, chats, and things I want to remember. Most of them are only useful for a short time, but they stay in my Photos app, take up storage, and get harder to organize.

Deleting them one by one takes too much time, so I usually put it off. I wanted an easier way to review only my old screenshots and quickly decide what to keep or delete.

## The solution

Sift makes cleaning up screenshots quick.

- **See only old screenshots.** Sift shows screenshots that are more than 30 days old. Your regular photos and newer screenshots are left untouched.
- **Swipe to decide.** You look at one screenshot at a time. Swipe left to move it to Trash, right to Archive, or up to Favorites.
- **Delete everything at the end.** Screenshots in Trash are not deleted right away. You can look through them first and then delete them all at once.
- **Undo mistakes.** If you swipe the wrong way, you can undo the last swipe. You can also restore screenshots from Trash before you delete them.
- **Get a monthly reminder.** Sift can remind you every 30 days when it's time to clean up again.

## How it works

<p align="center">
  <video src="docs/demo/sift-demo.mp4" poster="docs/demo/sift-demo-poster.png" width="280" controls muted playsinline></video>
</p>

<p align="center"><sub>Demo video, about 70 seconds, no sound. <a href="https://heejae92.github.io/Sift/docs/demo/sift-demo.mp4">Open the video</a></sub></p>

1. **Start.** Open Sift and allow access to your Photos. Sift only looks for screenshots that are more than 30 days old. Your photos stay on your phone.
2. **Review.** Sift shows one screenshot at a time. Swipe left for Trash, right for Archive, or up for Favorites. If you make a mistake, tap Rewind to undo the last swipe.
3. **Finish.** When there are no screenshots left to review, you're done. You can also turn on a reminder for your next cleanup.
4. **Delete.** Open Trash to see the screenshots you chose to remove. You can restore anything you want to keep, or delete everything at once.
5. **Find saved screenshots.** Open Library to see the screenshots you kept in Favorites or Archive.

## Try it

Try the Sift simulator in your browser. Swipe the sample screenshots left, right, or up to see how Sift works. Nothing you do in the simulator is saved or sent anywhere.

<p align="center">
  <iframe src="simulator.html" title="Sift simulator" width="100%" height="900" style="border:0; max-width:460px; height:min(960px, 92vh)" loading="lazy"></iframe>
</p>

<p align="center"><sub><a href="https://heejae92.github.io/Sift/simulator.html">Open the simulator on its own page</a></sub></p>

---

Course project for IXD 750 Product Innovation, Academy of Art University, 2026.

**More:** [Simulator](https://heejae92.github.io/Sift/simulator.html) · [GitHub](https://github.com/Heejae92/Sift) · [Design System](https://heejae92.github.io/Sift/design-system.html) · [App Structure](https://heejae92.github.io/Sift/ia.html) · [Developer Notes](https://github.com/Heejae92/Sift/blob/main/docs/DEVELOPMENT.md)
