<script lang="ts">
  import { tick } from "svelte";
  import { innerHTML } from "diffhtml";

  document.querySelector("body")?.setAttribute("for", "html-export");
  const url = new URL(window.location.href);
  const socket = new WebSocket(`ws://${url.hostname}:${url.port}/`);
  socket.addEventListener("message", async (event) => {
    const command = JSON.parse(event.data);
    noteHtml = command.params.html;
    noteTitle = command.params.html;
    innerHTML(document.body, noteHtml);
    await tick();
    let scriptText = document.querySelector("body>script")?.innerHTML;
    if (scriptText) {
      let scriptTextNode = document.createTextNode(scriptText);
      let newScript = document.createElement("script");
      newScript.appendChild(scriptTextNode);
      document.querySelector("body")?.appendChild(newScript);
    }
  })
  let noteHtml = "";
  let noteTitle = "";
</script>

<!-- {@html noteHtml} -->

<!-- <body for="html-export" /> -->
