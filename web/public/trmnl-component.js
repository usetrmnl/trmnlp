(function () {
  // Define the HTML template as a string.
  // We wrap the SVG in a container <div id="container"> to allow forwarding
  // of the host element's "class" and "style" attributes.

  let mainContentId = `main-content-${Math.random().toString(36).substring(2)}`;
  let containerId = `container-${Math.random().toString(36).substring(2)}`;
  let contentWrapperId = `container-wrapper-${Math.random()
    .toString(36)
    .substring(2)}`;
  let trmnlComponentIframeId = `trmnl-component-iframe-${Math.random()
    .toString(36)
    .substring(2)}`;

  const colors = {
    white: {
      start: "#F7F6F6",
      end: "#E9E9E9",
      logo: "#E9E9E9",
    },
    black: {
      start: "#414141",
      end: "#313131",
      logo: "#595959",
    },
    mint: {
      start: "#D9DED0",
      end: "#CFD3C8",
      logo: "#D8DCD1",
    },
    gray: {
      start: "#696e74",
      end: "#696e74",
      logo: "#595959",
    },
    wood: {
      start: "#f9e3cb",
      end: "#ecd4bc",
      logo: "#fdefd5",
    },
  };

  const contentWrapperTemplate = `<!doctype html>
<html lang="en">
    <head>
        <link rel="stylesheet" href="https://usetrmnl.com/css/latest/plugins.css"/>
        <script type="text/javascript" src="https://usetrmnl.com/js/latest/plugins.js"></script>
        <link rel="stylesheet" href="https://rsms.me/inter/inter.css">
        <meta charset="utf-8" />
        <title>TRMNL</title>
    </head>
    <body class="trmnl"  style="background-color: white !important;">
      <div id="${mainContentId}">CONTENT_PLACEHOLDER</div>
    </body>
</html>`;

  const templateHTML = `
    <style>
      :host {
        display: inline-block;
        width: auto;
      }
      #${containerId} {
        width: 100%;
        height: auto;
      }
      svg {
        width: 100%;
        height: auto;
        display: block;
      }
      #${mainContentId} {
        width: 100%;
        height: auto;
        display: block;
        background-opacity: 0;
      }
      #${trmnlComponentIframeId} {
        border: none !important;
        width: 800px;
        height: 480px;
      }
      #${trmnlComponentIframeId}.dark-mode {
        filter: invert(1) brightness(0.9) sepia(25%) contrast(0.75);
        opacity:90%;
      }
    </style>
    <div id="${containerId}">
    <svg width="950px" height="639px" viewBox="0 0 950 639" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                <title>TRMNL</title>
                <defs>
                    <linearGradient x1="50%" y1="0.295017483%" x2="50%" y2="98.7079327%" id="linearGradient-1">
                        <stop id="start" stop-color="#F7F6F6" offset="0%"></stop>
                        <stop id="end" stop-color="#E9E9E9" offset="100%"></stop>
                    </linearGradient>
                    <path d="M28.2027372,0 L826.111263,1.81366828e-15 C835.917969,-1.0537935e-15 839.474118,1.02108172 843.059303,2.93845974 C846.644488,4.85583776 849.458162,7.66951208 851.37554,11.2546973 C853.292918,14.8398824 854.314,18.3960311 854.314,28.2027372 L854.314,546.429263 C854.314,556.235969 853.292918,559.792118 851.37554,563.377303 C849.458162,566.962488 846.644488,569.776162 843.059303,571.69354 C839.474118,573.610918 835.917969,574.632 826.111263,574.632 L28.2027372,574.632 C18.3960311,574.632 14.8398824,573.610918 11.2546973,571.69354 C7.66951208,569.776162 4.85583776,566.962488 2.93845974,563.377303 C1.02108172,559.792118 1.79144895e-14,556.235969 -3.08323607e-14,546.429263 L0,28.2027372 C0,18.3960311 1.02108172,14.8398824 2.93845974,11.2546973 C4.85583776,7.66951208 7.66951208,4.85583776 11.2546973,2.93845974 C14.8398824,1.02108172 18.3960311,0 28.2027372,0 Z" id="path-2"></path>
                    <filter x="-1.3%" y="-1.7%" width="102.7%" height="104.0%" filterUnits="objectBoundingBox" id="filter-3">
                        <feOffset dx="0" dy="2" in="SourceAlpha" result="shadowOffsetOuter1"></feOffset>
                        <feGaussianBlur stdDeviation="3.5" in="shadowOffsetOuter1" result="shadowBlurOuter1"></feGaussianBlur>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.342083698 0" type="matrix" in="shadowBlurOuter1"></feColorMatrix>
                    </filter>
                    <path d="M38.5374834,27 L815.462517,27 C819.474351,27 820.929139,27.4177153 822.395806,28.2020972 C823.862472,28.9864791 825.013521,30.1375277 825.797903,31.6041943 C826.582285,33.070861 827,34.5256491 827,38.5374834 L827,495.462517 C827,499.474351 826.582285,500.929139 825.797903,502.395806 C825.013521,503.862472 823.862472,505.013521 822.395806,505.797903 C820.929139,506.582285 819.474351,507 815.462517,507 L38.5374834,507 C34.5256491,507 33.070861,506.582285 31.6041943,505.797903 C30.1375277,505.013521 28.9864791,503.862472 28.2020972,502.395806 C27.4177153,500.929139 27,499.474351 27,495.462517 L27,38.5374834 C27,34.5256491 27.4177153,33.070861 28.2020972,31.6041943 C28.9864791,30.1375277 30.1375277,28.9864791 31.6041943,28.2020972 C33.070861,27.4177153 34.5256491,27 38.5374834,27 Z" id="path-4"></path>
                    <filter x="-0.5%" y="-0.8%" width="101.0%" height="101.7%" filterUnits="objectBoundingBox" id="filter-5">
                        <feGaussianBlur stdDeviation="3" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="2" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-6" points="30.4432432 6.94287907 30.4432432 4.15135135 46.3567568 4.15135135 46.3567568 6.94287907 39.9198299 6.94287907 39.9198299 18.6810811 36.8990438 18.6810811 36.8990438 6.94287907"></polygon>
                    <filter x="-9.4%" y="-10.3%" width="118.9%" height="120.6%" filterUnits="objectBoundingBox" id="filter-7">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <path d="M49.8162162,4.15135135 L49.8162162,18.6810811 L52.8523226,18.6810811 L52.8523226,13.5912453 L61.0721342,13.5912453 C61.6443807,13.5912453 62.0184369,13.7189233 62.2506098,13.9435637 C62.4783178,14.1639612 62.6184648,14.5256765 62.6184648,15.1152338 L62.6184648,18.6810811 L65.6357196,18.6810811 L65.6357196,14.7403994 C65.6357196,13.8468096 65.3447594,13.1148672 64.814929,12.600511 C64.5115665,12.3061097 64.1385024,12.0909964 63.7133483,11.9555874 C64.2208543,11.696457 64.6412955,11.3548891 64.9652461,10.932914 C65.4762248,10.2674527 65.7297297,9.42496011 65.7297297,8.44713669 C65.7297297,7.06980219 65.2916771,5.97468682 64.3582728,5.23449284 C63.4382632,4.50512742 62.0749919,4.15135135 60.2825977,4.15135135 L49.8162162,4.15135135 Z M59.75624,10.8786151 L52.8523226,10.8786151 L52.8523226,6.84422472 L59.75624,6.84422472 C60.760834,6.84422472 61.4784366,6.9832779 61.9403018,7.28832549 C62.3756259,7.57590683 62.6184648,8.03546952 62.6184648,8.8022403 C62.6184648,9.5814535 62.3733935,10.0741526 61.9328604,10.3878162 C61.4714913,10.7164471 60.7551289,10.8786151 59.75624,10.8786151 Z" id="path-8"></path>
                    <filter x="-9.4%" y="-10.3%" width="118.9%" height="120.6%" filterUnits="objectBoundingBox" id="filter-9">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-10" points="68.4972973 18.6810811 68.4972973 4.15135135 72.9082435 4.15135135 79.241009 15.0102802 85.554257 4.15135135 89.9459459 4.15135135 89.9459459 18.6810811 86.7802138 18.6810811 86.7802138 7.96393861 80.6210236 18.6810811 77.8417371 18.6810811 71.6825469 7.96393861 71.6825469 18.6810811"></polygon>
                    <filter x="-7.0%" y="-10.3%" width="114.0%" height="120.6%" filterUnits="objectBoundingBox" id="filter-11">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-12" points="97.435008 4.15135135 93.4054054 4.15135135 93.4054054 18.6810811 96.4068254 18.6810811 96.4068254 7.50994637 105.999845 18.6810811 110.010811 18.6810811 110.010811 4.15135135 107.028027 4.15135135 107.028027 15.3224861"></polygon>
                    <filter x="-9.0%" y="-10.3%" width="118.1%" height="120.6%" filterUnits="objectBoundingBox" id="filter-13">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-14" points="117.380019 4.15135135 114.162162 4.15135135 114.162162 18.6810811 128 18.6810811 128 15.8895534 117.380019 15.8895534"></polygon>
                    <filter x="-10.8%" y="-10.3%" width="121.7%" height="120.6%" filterUnits="objectBoundingBox" id="filter-15">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-16" points="6.1435832 0.691891892 13.1459459 3.37533695 11.845606 6.91891892 4.84324324 4.2354993"></polygon>
                    <filter x="-18.1%" y="-24.1%" width="136.1%" height="148.2%" filterUnits="objectBoundingBox" id="filter-17">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-18" points="17.5964512 0 20.0648649 7.15103824 16.3062515 8.3027027 13.8378378 1.15166697"></polygon>
                    <filter x="-24.1%" y="-18.1%" width="148.2%" height="136.1%" filterUnits="objectBoundingBox" id="filter-19">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-20" points="25.6 8.27152584 21.2525567 14.5297297 17.9891892 12.4852309 22.3366325 6.22702703"></polygon>
                    <filter x="-19.7%" y="-18.1%" width="139.4%" height="136.1%" filterUnits="objectBoundingBox" id="filter-21">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-22" points="22.8324324 20.0099988 15.5472692 20.7567568 15.2216216 16.6602715 22.5067605 15.9135135"></polygon>
                    <filter x="-19.7%" y="-31.0%" width="139.4%" height="161.9%" filterUnits="objectBoundingBox" id="filter-23">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-24" points="14.009405 24.9081081 8.99459459 19.2742777 11.590595 16.6054054 16.6054054 22.2392877"></polygon>
                    <filter x="-19.7%" y="-18.1%" width="139.4%" height="136.1%" filterUnits="objectBoundingBox" id="filter-25">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-26" points="2.76756757 20.9711149 3.9545589 13.8378378 8.3027027 14.3153716 7.11571137 21.4486486"></polygon>
                    <filter x="-27.1%" y="-19.7%" width="154.2%" height="139.4%" filterUnits="objectBoundingBox" id="filter-27">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                    <polygon id="path-28" points="0 10.0113136 6.40614303 6.22702703 8.3027027 9.36165939 1.89655719 13.1459459"></polygon>
                    <filter x="-18.1%" y="-21.7%" width="136.1%" height="143.4%" filterUnits="objectBoundingBox" id="filter-29">
                        <feGaussianBlur stdDeviation="1" in="SourceAlpha" result="shadowBlurInner1"></feGaussianBlur>
                        <feOffset dx="0" dy="1" in="shadowBlurInner1" result="shadowOffsetInner1"></feOffset>
                        <feComposite in="shadowOffsetInner1" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="shadowInnerInner1"></feComposite>
                        <feColorMatrix values="0 0 0 0 0   0 0 0 0 0   0 0 0 0 0  0 0 0 0.5 0" type="matrix" in="shadowInnerInner1"></feColorMatrix>
                    </filter>
                </defs>
                <g id="Artboard" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" >
                    <g id="Group" transform="translate(48, 32)">
                        <g id="Rectangle">
                            <use fill="black" fill-opacity="1" filter="url(#filter-3)" xlink:href="#path-2"></use>
                            <use fill="url(#linearGradient-1)" fill-rule="evenodd" xlink:href="#path-2"></use>
                        </g>
                        <g id="Rectangle">
                            <use fill="#E4E2E1" fill-rule="evenodd" xlink:href="#path-4"></use>
                            <use fill="black" fill-opacity="1" filter="url(#filter-5)" xlink:href="#path-4"></use>
                        </g>



                       <foreignobject  class="node" x="36" y="34" width="840" height="520"
                                      style="transform:scale(0.98);  position: relative;  border-radius: 12px; opacity: 0.9; mix-blend-mode: darken;">
                         <div id="${contentWrapperId}"
                             style="position: static; width: 100%; height: 100%;  max-width: 100%; max-height: 100%;">
                           <iframe id="${trmnlComponentIframeId}" src="about:blank"
                                   style="display:block; position: static; top: 0; left: 0; width: 100%; height: 100%; border: none;"></iframe>
                         </div>
                       </foreignobject>

                       <g id="logo--brand@vector" transform="translate(363, 529)">
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-6"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-7)"
                                   xlink:href="#path-6"
                               ></use>
                           </g>
                           <g id="Shape">
                               <use
                                  class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-8"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-9)"
                                   xlink:href="#path-8"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-10"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-11)"
                                   xlink:href="#path-10"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-12"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-13)"
                                   xlink:href="#path-12"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                  class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-14"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-15)"
                                   xlink:href="#path-14"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-16"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-17)"
                                   xlink:href="#path-16"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-18"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-19)"
                                   xlink:href="#path-18"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-20"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-21)"
                                   xlink:href="#path-20"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-22"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-23)"
                                   xlink:href="#path-22"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-24"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-25)"
                                   xlink:href="#path-24"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-26"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-27)"
                                   xlink:href="#path-26"
                               ></use>
                           </g>
                           <g id="Path">
                               <use
                                   class="logo__path"
                                   fill="#E9E9E9"
                                   fill-rule="evenodd"
                                   xlink:href="#path-28"
                               ></use>
                               <use
                                   fill="black"
                                   fill-opacity="1"
                                   filter="url(#filter-29)"
                                   xlink:href="#path-28"
                               ></use>
                           </g>
                       </g>
                   </g>
               </g>
               </svg>
            </div>
  `;

  class TRMNL extends HTMLElement {
    constructor() {
      super();
      console.log("TRMNL element constructed.");
      this._src = null; // Store the src attribute value
      this._color = "white"; // Default color
      this._contentMode = "external"; // Default to external src mode
      this._htmlContent = ""; // Store HTML content
      this._darkMode = null; // Store dark mode setting

      // Attach a shadow root and append the template content
      const shadow = this.attachShadow({ mode: "open" });
      const template = document.createElement("template");
      template.innerHTML = templateHTML;
      shadow.appendChild(template.content.cloneNode(true));

      // Get reference to the iframe for later use
      this._iframe = this.shadowRoot.querySelector(
        `#${trmnlComponentIframeId}`
      );

      // Setup iframe load handler once
      if (this._iframe) {
        this._iframe.onload = () => {
          this._handleIframeLoaded();
        };
      }

      // Process any slotted content
      this._processSlottedContent();

      // Initialize dark mode media query listener if needed
      this._darkModeMediaQuery = window.matchMedia(
        "(prefers-color-scheme: dark)"
      );
      this._darkModeMediaQuery.addEventListener("change", () => {
        this._updateDarkMode();
      });
    }

    _handleIframeLoaded() {
      if (this._contentMode === "internal" && this._htmlContent) {
        try {
          const currentSrc = this._iframe.getAttribute("src");
          if (currentSrc === "about:blank") {
            const iframeDoc = this._iframe.contentWindow.document;

            // Step 1: Write the base shell with placeholder container
            iframeDoc.open();
            iframeDoc.write(
              contentWrapperTemplate.replace(
                `<div id="${mainContentId}">CONTENT_PLACEHOLDER</div>`,
                `<div id="${mainContentId}"></div>`
              )
            );
            iframeDoc.close();

            // Step 2: Wait for the contentWrapperTemplate to parse & render
            this._iframe.contentWindow.addEventListener(
              "DOMContentLoaded",
              () => {
                const container = iframeDoc.getElementById(mainContentId);
                if (!container) {
                  console.warn(
                    `${mainContentId} container not found inside iframe`
                  );
                  return;
                }

                // Step 3: Apply the transition & inject content
                // Check if not Safari and if startViewTransition is available
                const isSafari = /^((?!chrome|android).)*safari/i.test(
                  navigator.userAgent
                );
                if (
                  !isSafari &&
                  typeof iframeDoc.startViewTransition === "function"
                ) {
                  iframeDoc.startViewTransition(() => {
                    container.innerHTML = this._htmlContent;
                  });
                } else {
                  container.innerHTML = this._htmlContent;
                }

                console.log(
                  "Dynamic content injected" +
                    (!isSafari ? " with View Transition" : "")
                );
              },
              { once: true }
            );

            const isSafari = /^((?!chrome|android).)*safari/i.test(
              navigator.userAgent
            );
            if (isSafari) {
              console.log("Safari browser detected");
            }
            // Safari needs additional help to render content correctly
            if (isSafari) {
              const container = iframeDoc.getElementById(mainContentId);

              setTimeout(() => {
                if (container && this._htmlContent) {
                  container.innerHTML = this._htmlContent;
                  console.log(
                    "Applied additional Safari-specific content update"
                  );
                }
              }, 100);
            }
          }
        } catch (e) {
          console.error("Error injecting HTML with transition into iframe:", e);
        }
      }
    }

    static get observedAttributes() {
      return ["src", "class", "style", "color", "dark"];
    }

    attributeChangedCallback(name, oldValue, newValue) {
      if (name === "src") {
        console.log(
          `attributeChangedCallback: 'src' changed from ${oldValue} to ${newValue}`
        );
        this._src = newValue;
        this._contentMode = "external";
        this.updateIframe();
      } else if (name === "class" || name === "style") {
        this.updateContainerAttribute(name, newValue);
      } else if (name === "color") {
        this._color = newValue || "white"; // Default to white if not specified
        this.updateColors();
      } else if (name === "dark") {
        this._darkMode = newValue;
        this._updateDarkMode();
      }
    }

    connectedCallback() {
      console.log("TRMNL connectedCallback invoked.");

      // Process any existing content from innerHTML
      this._processSlottedContent();

      if (this.hasAttribute("src")) {
        const src = this.getAttribute("src");
        console.log("connectedCallback found src attribute:", src);
        this._src = src;
        this._contentMode = "external";
        this.updateIframe();
      }

      // Initialize container attributes for class and style
      this.updateContainerAttribute("class", this.getAttribute("class"));
      this.updateContainerAttribute("style", this.getAttribute("style"));

      // Initialize color
      if (this.hasAttribute("color")) {
        this._color = this.getAttribute("color");
      }
      this.updateColors();

      // Initialize dark mode
      if (this.hasAttribute("dark")) {
        this._darkMode = this.getAttribute("dark");
        this._updateDarkMode();
      }

      // Set up the mutation observer to handle content changes
      this._setupMutationObserver();
    }

    disconnectedCallback() {
      // Clean up the mutation observer when element is removed
      if (this._observer) {
        this._observer.disconnect();
      }

      // Remove media query listener
      if (this._darkModeMediaQuery) {
        this._darkModeMediaQuery.removeEventListener("change", () => {
          this._updateDarkMode();
        });
      }
    }

    _updateDarkMode() {
      if (!this._iframe) return;

      // Step 1: Remove the class
      this._iframe.classList.remove("dark-mode");

      // Step 2: Force reflow by reading offsetHeight
      // This ensures the class removal is flushed
      void this._iframe.offsetHeight;

      // Step 3: Re-apply the class based on logic
      const shouldEnableDark =
        this._darkMode === "true" ||
        (this._darkMode === "auto" && this._darkModeMediaQuery.matches);

      if (shouldEnableDark) {
        this._iframe.classList.add("dark-mode");
      }
    }

    _setupMutationObserver() {
      // Create a MutationObserver to detect content changes
      this._observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === "childList") {
            this._processSlottedContent();
          }
        });
      });

      // Observe changes to the element's child nodes
      this._observer.observe(this, { childList: true });
    }

    _processSlottedContent() {
      // Check if there's content inside the tags
      if (this.innerHTML.trim()) {
        // Set content mode to internal and store HTML
        this._contentMode = "internal";
        this._htmlContent = this.innerHTML;
        this._prepareThenInjectHTML();
      }
    }

    _prepareThenInjectHTML() {
      if (!this._iframe) {
        console.error("Iframe not found in shadow DOM");
        return;
      }

      // Set iframe to about:blank to ensure same-origin
      // This will trigger the onload handler which will inject the content
      this._iframe.setAttribute("src", "about:blank");
    }

    updateIframe() {
      // Delay updating the iframe until the next animation frame
      requestAnimationFrame(() => {
        if (this._iframe) {
          if (this._contentMode === "external" && this._src) {
            this._iframe.setAttribute("src", this._src);
            console.log(`iframe src set to: ${this._src}`);
          } else if (this._contentMode === "internal") {
            // For internal content, ensure we're at about:blank
            this._prepareThenInjectHTML();
          }
        } else {
          console.error(
            "iframe element not found in shadow DOM during updateIframe."
          );
        }
      });
    }

    updateContainerAttribute(name, value) {
      const container = this.shadowRoot.querySelector("#container");
      if (container) {
        if (value !== null) {
          container.setAttribute(name, value);
        } else {
          container.removeAttribute(name);
        }
      }
    }

    updateColors() {
      // Validate that the color exists in our colors object
      if (!colors[this._color]) {
        console.warn(`Color "${this._color}" not found, defaulting to white`);
        this._color = "white";
      }

      const colorSet = colors[this._color];

      // Update the gradient stops
      const startStop = this.shadowRoot.querySelector("#start");
      const endStop = this.shadowRoot.querySelector("#end");

      if (startStop && endStop) {
        startStop.setAttribute("stop-color", colorSet.start);
        endStop.setAttribute("stop-color", colorSet.end);
        console.log(`Updated gradient colors to ${this._color} theme`);
      }

      // Update all SVG elements in the logo that use the fill color
      const logoGroup = this.shadowRoot.querySelector("#logo--brand\\@vector");
      if (logoGroup) {
        // Find all 'use' elements with fill="#E9E9E9" and update them
        const logoElements = logoGroup.querySelectorAll(".logo__path");
        logoElements.forEach((element) => {
          element.setAttribute("fill", colorSet.logo);
        });
      }
    }

    // JavaScript API methods

    /**
     * Set the color theme: 'white', 'black', or 'mint'
     * @param {string} color - The color theme to use
     */
    setColor(color) {
      this._color = color;
      this.updateColors();
      return this; // For chaining
    }

    /**
     * Set dark mode: 'true', 'false', or 'auto'
     * @param {string} mode - The dark mode setting
     */
    setDark(mode) {
      this._darkMode = mode;
      this._updateDarkMode();
      return this; // For chaining
    }

    /**
     * Set HTML content directly, wrapping it in the template
     * @param {string} html - HTML content to display
     */
    setHTML(html) {
      this._contentMode = "internal";
      this._htmlContent = html;
      this._prepareThenInjectHTML();
      return this; // For chaining
    }

    /**
     * Clear all content
     */
    clearContent() {
      if (this._iframe) {
        this._htmlContent = "";

        if (this._contentMode === "internal") {
          // Reset to about:blank to clear content
          this._iframe.setAttribute("src", "about:blank");
        } else {
          // For external mode, set src to empty
          this._src = "";
          this._iframe.setAttribute("src", "about:blank");
        }
      }
      return this; // For chaining
    }

    /**
     * Set iframe source to an external URL
     * @param {string} src - URL to load in the iframe
     */
    setSrc(src) {
      this._contentMode = "external";
      this._src = src;
      this.updateIframe();
      return this; // For chaining
    }

    /**
     * Get current HTML content (for internal content mode only)
     * @returns {string} The current HTML content or empty string if in external mode
     */
    getHTML() {
      // Simply return the stored HTML content
      return this._contentMode === "internal" ? this._htmlContent : "";
    }

    /**
     * Set dark mode: 'true', 'false', or 'auto'
     * @param {string} mode - The dark mode setting
     */
    setDarkMode(mode) {
      this._darkMode = mode;
      this._updateDarkMode();
      return this; // For chaining
    }
  }

  // Register the custom element using a hyphenated tag name
  customElements.define("trmnl-frame", TRMNL);
})();
