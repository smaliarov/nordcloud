package net.notejam.spring.pad.controller;

import javax.validation.Valid;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.util.UriComponentsBuilder;

import net.notejam.spring.URITemplates;
import net.notejam.spring.error.ResourceNotFoundException;
import net.notejam.spring.pad.Pad;
import net.notejam.spring.pad.PadService;
import net.notejam.spring.pad.controller.PadsAdvice.Pads;

/**
 * The edit pad controller.
 *
 * @author markus@malkusch.de
 * @see <a href="bitcoin:1335STSwu9hST4vcMRppEPgENMHD2r1REK">Donations</a>
 */
@Controller
@RequestMapping(URITemplates.EDIT_PAD)
@PreAuthorize("isAuthenticated()")
@Pads
public class EditPadController {

    @Autowired
    private PadService service;

    @ModelAttribute
    public Pad pad(@PathVariable("id") int id) {
        return service.getPad(id).orElseThrow(() -> new ResourceNotFoundException());
    }

    @ModelAttribute("deleteURI")
    public String deleteURI(@PathVariable("id") int id) {
        UriComponentsBuilder uriBuilder = UriComponentsBuilder.fromPath(URITemplates.DELETE_PAD);
        return uriBuilder.buildAndExpand(id).toUriString();
    }

    /**
     * Shows the form for creating a pad.
     * 
     * @return The view
     */
    @RequestMapping(method = RequestMethod.GET)
    public String showCreatePadForm() {
        return "pad/edit";
    }

    /**
     * Shows the form for creating a pad.
     * 
     * @return The view
     */
    @RequestMapping(method = RequestMethod.POST)
    public String createPad(@Valid Pad pad, BindingResult bindingResult) {
        if (bindingResult.hasErrors()) {
            return "pad/edit";
        }

        service.savePad(pad);

        return String.format("redirect:%s", buildEditedPadUri(pad.getId()));
    }

    /**
     * Builds the URI for the edited pad.
     * 
     * @param id
     *            The pad id
     * @return The URI
     */
    private String buildEditedPadUri(int id) {
        UriComponentsBuilder uriBuilder = UriComponentsBuilder.fromPath(URITemplates.EDIT_PAD);
        uriBuilder.queryParam("success");
        return uriBuilder.buildAndExpand(id).toUriString();
    }

}
